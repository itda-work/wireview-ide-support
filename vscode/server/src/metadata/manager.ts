/**
 * Metadata manager for wireview components.
 *
 * Handles loading and caching component metadata from Python.
 */

import { spawn } from "child_process";
import * as fs from "fs";
import * as path from "path";

import { WireviewMetadata, ComponentMetadata } from "./types.js";

export { WireviewMetadata, ComponentMetadata };

interface WireviewSettings {
  pythonPath: string;
  djangoSettingsModule: string;
  autoRefreshMetadata: boolean;
  metadataPath: string;
}

export class MetadataManager {
  private metadata: WireviewMetadata | null = null;
  private workspaceRoot: string;
  private settings: WireviewSettings;

  constructor(workspaceRoot: string, settings: WireviewSettings) {
    this.workspaceRoot = workspaceRoot;
    this.settings = settings;
  }

  updateSettings(settings: WireviewSettings): void {
    this.settings = settings;
  }

  getMetadata(): WireviewMetadata | null {
    return this.metadata;
  }

  getComponent(name: string): ComponentMetadata | undefined {
    if (!this.metadata) return undefined;

    // Try direct lookup first
    if (this.metadata.components[name]) {
      return this.metadata.components[name];
    }

    // Try FQN lookup
    for (const component of Object.values(this.metadata.components)) {
      if (component.fqn === name || component.app_key === name) {
        return component;
      }
    }

    return undefined;
  }

  getAllComponentNames(): string[] {
    if (!this.metadata) return [];
    return Object.keys(this.metadata.components);
  }

  async refresh(): Promise<void> {
    // Try to load from cache file first
    const cacheLoaded = await this.loadFromCache();

    // If cache is recent enough, don't refresh from Python
    if (cacheLoaded) {
      return;
    }

    // Run Python command to generate fresh metadata
    await this.runPythonExtractor();
  }

  private async loadFromCache(): Promise<boolean> {
    const cachePath = path.join(this.workspaceRoot, this.settings.metadataPath);

    try {
      if (!fs.existsSync(cachePath)) {
        return false;
      }

      const content = fs.readFileSync(cachePath, "utf-8");
      this.metadata = JSON.parse(content) as WireviewMetadata;

      // Check if cache is recent (less than 5 minutes old)
      const generatedAt = new Date(this.metadata.generated_at);
      const now = new Date();
      const ageMs = now.getTime() - generatedAt.getTime();
      const maxAgeMs = 5 * 60 * 1000; // 5 minutes

      return ageMs < maxAgeMs;
    } catch {
      return false;
    }
  }

  private async runPythonExtractor(): Promise<void> {
    return new Promise((resolve, reject) => {
      const outputPath = path.join(
        this.workspaceRoot,
        this.settings.metadataPath
      );

      // Find manage.py
      const managePy = this.findManagePy();
      if (!managePy) {
        reject(new Error("manage.py not found in workspace"));
        return;
      }

      const args = [managePy, "wireview_lsp", "--output", outputPath];

      // Add settings module if configured
      if (this.settings.djangoSettingsModule) {
        args.push("--settings", this.settings.djangoSettingsModule);
      }

      const child = spawn(this.settings.pythonPath, args, {
        cwd: this.workspaceRoot,
        env: {
          ...process.env,
          DJANGO_SETTINGS_MODULE: this.settings.djangoSettingsModule || undefined,
        },
      });

      let stderr = "";

      child.stderr.on("data", (data) => {
        stderr += data.toString();
      });

      child.on("close", async (code) => {
        if (code === 0) {
          // Reload from the newly generated cache
          await this.loadFromCache();
          resolve();
        } else {
          reject(new Error(`Python command failed: ${stderr}`));
        }
      });

      child.on("error", (error) => {
        reject(new Error(`Failed to spawn Python: ${error.message}`));
      });
    });
  }

  private findManagePy(): string | null {
    // Common locations for manage.py
    const candidates = [
      path.join(this.workspaceRoot, "manage.py"),
      path.join(this.workspaceRoot, "src", "manage.py"),
      path.join(this.workspaceRoot, "backend", "manage.py"),
      path.join(this.workspaceRoot, "tests", "manage.py"),
      path.join(this.workspaceRoot, "example", "manage.py"),
    ];

    for (const candidate of candidates) {
      if (fs.existsSync(candidate)) {
        return candidate;
      }
    }

    // Try to find it recursively (max depth 3)
    return this.findFileRecursive(this.workspaceRoot, "manage.py", 3);
  }

  private findFileRecursive(
    dir: string,
    filename: string,
    maxDepth: number
  ): string | null {
    if (maxDepth <= 0) return null;

    try {
      const entries = fs.readdirSync(dir, { withFileTypes: true });

      for (const entry of entries) {
        if (entry.name === filename && entry.isFile()) {
          return path.join(dir, entry.name);
        }
      }

      for (const entry of entries) {
        if (
          entry.isDirectory() &&
          !entry.name.startsWith(".") &&
          entry.name !== "node_modules" &&
          entry.name !== "__pycache__" &&
          entry.name !== "venv" &&
          entry.name !== ".venv"
        ) {
          const found = this.findFileRecursive(
            path.join(dir, entry.name),
            filename,
            maxDepth - 1
          );
          if (found) return found;
        }
      }
    } catch {
      // Ignore permission errors
    }

    return null;
  }
}

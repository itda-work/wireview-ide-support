/**
 * Django template parser for wireview tags.
 *
 * Parses template content to identify wireview-specific tags and
 * determine cursor context for autocompletion.
 */

export type CursorPosition =
  | "component_name"
  | "attribute_name"
  | "attribute_value"
  | "handler_name"
  | "event_name"
  | "modifier"
  | "slot_name"
  | "outside";

export interface CursorContext {
  inWireviewTag: boolean;
  tagType: "component" | "component_block" | "on" | "fill" | "render_slot" | null;
  position: CursorPosition;
  componentName?: string;
  currentValue?: string;
  attributeName?: string;
  eventName?: string;
}

interface TagMatch {
  type: string;
  startOffset: number;
  endOffset: number;
  content: string;
}

export class TemplateParser {
  // Regex patterns for wireview tags
  private static readonly TAG_START = /\{%\s*/g;
  private static readonly TAG_END = /\s*%\}/g;

  /**
   * Get the cursor context at a given offset in the template.
   */
  getCursorContext(content: string, offset: number): CursorContext {
    // Find enclosing tag
    const tag = this.findEnclosingTag(content, offset);

    if (!tag) {
      // Check if we're inside a component's template (for {% on %} context)
      const componentContext = this.findComponentContext(content, offset);
      return {
        inWireviewTag: false,
        tagType: null,
        position: "outside",
        componentName: componentContext,
      };
    }

    const tagType = this.detectTagType(tag.content);
    if (!tagType) {
      return {
        inWireviewTag: false,
        tagType: null,
        position: "outside",
      };
    }

    const relativeOffset = offset - tag.startOffset;

    switch (tagType) {
      case "component":
      case "component_block":
        return this.parseComponentTag(tag.content, relativeOffset, tagType);
      case "on":
        return this.parseOnTag(tag.content, relativeOffset);
      case "fill":
        return this.parseFillTag(tag.content, relativeOffset);
      case "render_slot":
        return this.parseRenderSlotTag(tag.content, relativeOffset);
      default:
        return {
          inWireviewTag: false,
          tagType: null,
          position: "outside",
        };
    }
  }

  /**
   * Find the Django template tag enclosing the given offset.
   */
  private findEnclosingTag(content: string, offset: number): TagMatch | null {
    // Find all {% ... %} blocks
    let startIndex = -1;
    let depth = 0;

    for (let i = 0; i < content.length; i++) {
      if (content.slice(i, i + 2) === "{%") {
        if (depth === 0) {
          startIndex = i;
        }
        depth++;
      } else if (content.slice(i, i + 2) === "%}") {
        depth--;
        if (depth === 0 && startIndex !== -1) {
          const endIndex = i + 2;
          if (offset >= startIndex && offset <= endIndex) {
            return {
              type: "",
              startOffset: startIndex,
              endOffset: endIndex,
              content: content.slice(startIndex, endIndex),
            };
          }
          startIndex = -1;
        }
      }
    }

    return null;
  }

  /**
   * Detect the type of wireview tag.
   */
  private detectTagType(
    tagContent: string
  ): "component" | "component_block" | "on" | "fill" | "render_slot" | null {
    const match = tagContent.match(/\{%\s*(\w+)/);
    if (!match) return null;

    const tagName = match[1];
    if (tagName === "component") return "component";
    if (tagName === "component_block") return "component_block";
    if (tagName === "on") return "on";
    if (tagName === "fill") return "fill";
    if (tagName === "render_slot") return "render_slot";

    return null;
  }

  /**
   * Parse a component or component_block tag.
   */
  private parseComponentTag(
    content: string,
    relativeOffset: number,
    tagType: "component" | "component_block"
  ): CursorContext {
    // Pattern: {% component 'Name' attr=value %}
    // Pattern: {% component_block "Name" attr=value %}

    const tagKeyword = tagType === "component" ? "component" : "component_block";
    const afterKeyword = content.indexOf(tagKeyword) + tagKeyword.length;

    // Check if we're in the component name
    const nameMatch = content.match(
      new RegExp(`\\{%\\s*${tagKeyword}\\s+['"]([^'"]*)['"\\s]?`)
    );

    if (nameMatch) {
      const nameStart = content.indexOf(nameMatch[0]) + nameMatch[0].indexOf(nameMatch[1]);
      const nameEnd = nameStart + nameMatch[1].length;

      // Check if cursor is within the component name
      if (relativeOffset >= nameStart && relativeOffset <= nameEnd + 1) {
        return {
          inWireviewTag: true,
          tagType,
          position: "component_name",
          currentValue: nameMatch[1].slice(0, relativeOffset - nameStart),
        };
      }

      // After the component name, we're in attribute territory
      if (relativeOffset > nameEnd) {
        return this.parseAttributeContext(content, relativeOffset, nameMatch[1], tagType);
      }
    }

    // Before or at component name
    const beforeName = content.slice(0, relativeOffset);
    if (beforeName.match(new RegExp(`\\{%\\s*${tagKeyword}\\s+['"]?$`))) {
      return {
        inWireviewTag: true,
        tagType,
        position: "component_name",
        currentValue: "",
      };
    }

    return {
      inWireviewTag: true,
      tagType,
      position: "attribute_name",
    };
  }

  /**
   * Parse attribute context (attr=value).
   */
  private parseAttributeContext(
    content: string,
    relativeOffset: number,
    componentName: string,
    tagType: "component" | "component_block"
  ): CursorContext {
    const beforeCursor = content.slice(0, relativeOffset);

    // Check if we're after an = (attribute value)
    const eqMatch = beforeCursor.match(/(\w+)\s*=\s*['"]?([^'"\s]*)$/);
    if (eqMatch) {
      return {
        inWireviewTag: true,
        tagType,
        position: "attribute_value",
        componentName,
        attributeName: eqMatch[1],
        currentValue: eqMatch[2],
      };
    }

    // Check if we're typing an attribute name
    const attrMatch = beforeCursor.match(/\s(\w*)$/);
    if (attrMatch) {
      return {
        inWireviewTag: true,
        tagType,
        position: "attribute_name",
        componentName,
        currentValue: attrMatch[1],
      };
    }

    return {
      inWireviewTag: true,
      tagType,
      position: "attribute_name",
      componentName,
    };
  }

  /**
   * Parse an {% on %} event tag.
   */
  private parseOnTag(content: string, relativeOffset: number): CursorContext {
    // Pattern: {% on 'event.modifier' 'handler' attr=value %}

    const beforeCursor = content.slice(0, relativeOffset);

    // Check for event name position (first quoted string)
    const eventStartMatch = beforeCursor.match(/\{%\s*on\s+['"]$/);
    if (eventStartMatch) {
      return {
        inWireviewTag: true,
        tagType: "on",
        position: "event_name",
        currentValue: "",
      };
    }

    // Check if we're in the event string with modifiers
    const eventMatch = content.match(/\{%\s*on\s+['"]([^'"]*)['"]/);
    if (eventMatch) {
      const eventStart =
        content.indexOf(eventMatch[0]) +
        eventMatch[0].indexOf(eventMatch[1]);
      const eventEnd = eventStart + eventMatch[1].length;

      if (relativeOffset >= eventStart && relativeOffset <= eventEnd) {
        const eventValue = eventMatch[1];
        const cursorInEvent = relativeOffset - eventStart;

        // Check if after a dot (modifier)
        if (eventValue.lastIndexOf(".") < cursorInEvent && eventValue.includes(".")) {
          return {
            inWireviewTag: true,
            tagType: "on",
            position: "modifier",
            eventName: eventValue.split(".")[0],
            currentValue: eventValue.slice(eventValue.lastIndexOf(".") + 1, cursorInEvent),
          };
        }

        return {
          inWireviewTag: true,
          tagType: "on",
          position: "event_name",
          currentValue: eventValue.slice(0, cursorInEvent),
        };
      }

      // After event string, check for handler
      const handlerStartMatch = beforeCursor.match(/\{%\s*on\s+['"][^'"]*['"]\s+['"]$/);
      if (handlerStartMatch) {
        return {
          inWireviewTag: true,
          tagType: "on",
          position: "handler_name",
          eventName: eventMatch[1].split(".")[0],
          currentValue: "",
        };
      }

      // Check if we're in the handler string
      const handlerMatch = content.match(
        /\{%\s*on\s+['"][^'"]*['"]\s+['"]([^'"]*)['"]?/
      );
      if (handlerMatch) {
        const fullMatch = handlerMatch[0];
        const handlerStart =
          content.indexOf(fullMatch) +
          fullMatch.lastIndexOf(handlerMatch[1]);
        const handlerEnd = handlerStart + handlerMatch[1].length;

        if (relativeOffset >= handlerStart && relativeOffset <= handlerEnd + 1) {
          return {
            inWireviewTag: true,
            tagType: "on",
            position: "handler_name",
            eventName: eventMatch[1].split(".")[0],
            currentValue: handlerMatch[1].slice(0, relativeOffset - handlerStart),
          };
        }
      }
    }

    return {
      inWireviewTag: true,
      tagType: "on",
      position: "event_name",
    };
  }

  /**
   * Parse a {% fill %} slot tag.
   */
  private parseFillTag(content: string, relativeOffset: number): CursorContext {
    // Pattern: {% fill slotname %} or {% fill slotname let:var %}

    const beforeCursor = content.slice(0, relativeOffset);

    // Check if we're in the slot name
    const slotMatch = beforeCursor.match(/\{%\s*fill\s+(\w*)$/);
    if (slotMatch) {
      return {
        inWireviewTag: true,
        tagType: "fill",
        position: "slot_name",
        currentValue: slotMatch[1],
      };
    }

    return {
      inWireviewTag: true,
      tagType: "fill",
      position: "slot_name",
    };
  }

  /**
   * Parse a {% render_slot %} tag.
   */
  private parseRenderSlotTag(
    content: string,
    relativeOffset: number
  ): CursorContext {
    // Pattern: {% render_slot %} or {% render_slot "name" %}

    const beforeCursor = content.slice(0, relativeOffset);

    // Check if we're after the opening quote
    const slotMatch = beforeCursor.match(/\{%\s*render_slot\s+['"]([^'"]*)$/);
    if (slotMatch) {
      return {
        inWireviewTag: true,
        tagType: "render_slot",
        position: "slot_name",
        currentValue: slotMatch[1],
      };
    }

    return {
      inWireviewTag: true,
      tagType: "render_slot",
      position: "slot_name",
    };
  }

  /**
   * Find the component context for {% on %} tags inside components.
   * Looks for the nearest parent component_block or wireview-component attribute.
   */
  private findComponentContext(
    content: string,
    offset: number
  ): string | undefined {
    // Look backwards for component_block opening
    const before = content.slice(0, offset);

    // Find last component_block opening
    const blockMatch = before.match(
      /\{%\s*component_block\s+['"](\w+)['"]/g
    );
    if (blockMatch) {
      const lastBlock = blockMatch[blockMatch.length - 1];
      const nameMatch = lastBlock.match(/['"](\w+)['"]/);
      if (nameMatch) {
        return nameMatch[1];
      }
    }

    // Look for wireview-component attribute in HTML
    const htmlMatch = before.match(/wireview-component=["'](\w+)["']/g);
    if (htmlMatch) {
      const lastAttr = htmlMatch[htmlMatch.length - 1];
      const nameMatch = lastAttr.match(/["'](\w+)["']/);
      if (nameMatch) {
        return nameMatch[1];
      }
    }

    return undefined;
  }
}

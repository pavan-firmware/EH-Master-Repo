const fs = require('fs');
const path = require('path');

class SchemaValidator {
  constructor() {
    this.schemas = new Map();
  }

  loadSchema(filePath) {
    const content = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    const id = content.$id || content.title || filePath;
    this.schemas.set(id, content);
    if (content.title) {
      this.schemas.set(content.title, content);
    }
    return content;
  }

  validate(schemaOrTitle, data) {
    const schema = typeof schemaOrTitle === 'string' 
      ? this.schemas.get(schemaOrTitle) 
      : schemaOrTitle;
    
    if (!schema) {
      return { valid: false, errors: [`Schema '${schemaOrTitle}' not found`] };
    }

    const errors = [];
    this._validateNode(schema, data, '#', errors);
    return { valid: errors.length === 0, errors };
  }

  _validateNode(schema, data, path, errors) {
    if (schema.$ref) {
      const refSchema = this.schemas.get(schema.$ref);
      if (!refSchema) {
        errors.push(`${path}: Unresolved $ref ${schema.$ref}`);
        return;
      }
      return this._validateNode(refSchema, data, path, errors);
    }

    if (data === undefined) {
      return;
    }

    // Type checking
    if (schema.type) {
      const types = Array.isArray(schema.type) ? schema.type : [schema.type];
      const actualType = this._getType(data);
      const isMatch = types.some(t => {
        if (t === actualType) return true;
        if (t === 'number' && actualType === 'integer') return true;
        return false;
      });
      if (!isMatch) {
        errors.push(`${path}: Expected type [${types.join(', ')}], got ${actualType}`);
        return;
      }
    }

    if (data === null) {
      return;
    }

    // Enum checking
    if (schema.enum && !schema.enum.includes(data)) {
      errors.push(`${path}: Value '${data}' is not in enum [${schema.enum.join(', ')}]`);
    }

    // String constraints
    if (typeof data === 'string') {
      if (schema.minLength !== undefined && data.length < schema.minLength) {
        errors.push(`${path}: Length ${data.length} < minLength ${schema.minLength}`);
      }
      if (schema.maxLength !== undefined && data.length > schema.maxLength) {
        errors.push(`${path}: Length ${data.length} > maxLength ${schema.maxLength}`);
      }
      if (schema.pattern && !new RegExp(schema.pattern).test(data)) {
        errors.push(`${path}: Value '${data}' does not match pattern ${schema.pattern}`);
      }
      if (schema.format === 'uuid' && !/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(data)) {
        errors.push(`${path}: Invalid UUID format '${data}'`);
      }
      if (schema.format === 'date-time' && isNaN(Date.parse(data))) {
        errors.push(`${path}: Invalid ISO date-time format '${data}'`);
      }
    }

    // Numeric constraints
    if (typeof data === 'number') {
      if (schema.minimum !== undefined && data < schema.minimum) {
        errors.push(`${path}: Value ${data} < minimum ${schema.minimum}`);
      }
      if (schema.maximum !== undefined && data > schema.maximum) {
        errors.push(`${path}: Value ${data} > maximum ${schema.maximum}`);
      }
    }

    // Object checking
    if (typeof data === 'object' && !Array.isArray(data)) {
      if (schema.required) {
        for (const req of schema.required) {
          if (!(req in data) || data[req] === undefined) {
            errors.push(`${path}: Missing required property '${req}'`);
          }
        }
      }

      const properties = schema.properties || {};
      for (const [key, val] of Object.entries(data)) {
        if (properties[key]) {
          this._validateNode(properties[key], val, `${path}.${key}`, errors);
        } else if (schema.additionalProperties === false) {
          errors.push(`${path}: Additional property '${key}' not allowed`);
        } else if (typeof schema.additionalProperties === 'object') {
          this._validateNode(schema.additionalProperties, val, `${path}.${key}`, errors);
        }
      }
    }

    // Array checking
    if (Array.isArray(data)) {
      if (schema.minItems !== undefined && data.length < schema.minItems) {
        errors.push(`${path}: Array length ${data.length} < minItems ${schema.minItems}`);
      }
      if (schema.items) {
        data.forEach((item, index) => {
          this._validateNode(schema.items, item, `${path}[${index}]`, errors);
        });
      }
    }
  }

  _getType(val) {
    if (val === null) return 'null';
    if (Array.isArray(val)) return 'array';
    if (typeof val === 'number') return Number.isInteger(val) ? 'integer' : 'number';
    return typeof val;
  }
}

module.exports = { SchemaValidator };

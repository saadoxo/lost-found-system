const Joi = require('joi');

// Password must be 12+ chars with upper, lower, number, and special character
const passwordPolicy = Joi.string()
  .min(12)
  .pattern(/[A-Z]/, 'uppercase letter')
  .pattern(/[a-z]/, 'lowercase letter')
  .pattern(/[0-9]/, 'number')
  .pattern(/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/, 'special character')
  .required()
  .messages({
    'string.min': 'Password must be at least 12 characters',
    'string.pattern.name': 'Password must contain a {#name}'
  });

exports.registerSchema = Joi.object({
  email:    Joi.string().email().lowercase().max(255).required(),
  password: passwordPolicy,
  name:     Joi.string().min(2).max(100).required()
});

exports.loginSchema = Joi.object({
  email:    Joi.string().email().required(),
  password: Joi.string().required()
});

exports.refreshSchema = Joi.object({
  refreshToken: Joi.string().required()
});

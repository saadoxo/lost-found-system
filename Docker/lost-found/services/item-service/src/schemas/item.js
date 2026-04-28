const Joi = require('joi');

const CATEGORIES = ['electronics','clothing','documents','keys','pets','bags','jewellery','other'];

exports.createItemSchema = Joi.object({
  type:        Joi.string().valid('lost', 'found').required(),
  title:       Joi.string().min(3).max(200).required(),
  description: Joi.string().max(2000).optional(),
  category:    Joi.string().valid(...CATEGORIES).required(),
  location:    Joi.string().max(300).required(),
  date:        Joi.string().isoDate().required(),
  imageKey:    Joi.string().optional()
});

exports.updateItemSchema = Joi.object({
  title:       Joi.string().min(3).max(200),
  description: Joi.string().max(2000),
  category:    Joi.string().valid(...CATEGORIES),
  location:    Joi.string().max(300),
  date:        Joi.string().isoDate(),
  imageKey:    Joi.string()
}).min(1);
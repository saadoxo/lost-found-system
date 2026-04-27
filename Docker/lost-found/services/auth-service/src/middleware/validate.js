// Validation middleware — wraps a Joi schema and returns 422 on failure
module.exports = (schema) => (req, res, next) => {
  const { error } = schema.validate(req.body, { abortEarly: false });

  if (error) {
    return res.status(422).json({
      error: 'Validation failed',
      details: error.details.map(d => d.message)
    });
  }

  next();
};

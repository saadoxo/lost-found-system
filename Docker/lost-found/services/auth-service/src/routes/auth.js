const express    = require('express');
const router     = express.Router();
const controller = require('../controllers/auth');
const validate   = require('../middleware/validate');
const authMiddleware = require('../middleware/auth');
const { registerSchema, loginSchema, refreshSchema } = require('../schemas/auth');

router.post('/register', validate(registerSchema), controller.register);
router.post('/login',    validate(loginSchema),    controller.login);
router.post('/refresh',  validate(refreshSchema),  controller.refresh);
router.post('/logout',   authMiddleware,            controller.logout);
router.get('/me',        authMiddleware,            controller.me);

module.exports = router;

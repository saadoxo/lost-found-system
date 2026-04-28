const express    = require('express');
const router     = express.Router();
const controller = require('../controllers/item');
const authMiddleware = require('../middleware/auth');
const validate   = require('../middleware/validate');
const { createItemSchema, updateItemSchema } = require('../schemas/item');

// Public
router.get('/',     controller.listItems);
router.get('/:id',  controller.getItem);

// Protected
router.post('/',    authMiddleware, validate(createItemSchema), controller.createItem);
router.put('/:id',  authMiddleware, validate(updateItemSchema), controller.updateItem);
router.delete('/:id', authMiddleware, controller.deleteItem);

module.exports = router;
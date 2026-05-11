const express        = require('express');
const router         = express.Router();
const controller     = require('../controllers/item');
const authMiddleware = require('../middleware/auth');
const validate       = require('../middleware/validate');
const { createItemSchema, updateItemSchema } = require('../schemas/item');

router.get('/',    controller.listItems);
router.get('/:id', controller.getItem);

router.post('/',    authMiddleware, validate(createItemSchema), controller.createItem);
router.put('/:id',  authMiddleware, validate(updateItemSchema), controller.updateItem);
router.delete('/:id', authMiddleware, controller.deleteItem);

router.post('/:id/claims',                 authMiddleware, controller.claimItem);
router.get('/:id/claims',                  authMiddleware, controller.getClaims);
router.put('/:id/claims/:claimId/approve', authMiddleware, controller.approveClaim);

module.exports = router;

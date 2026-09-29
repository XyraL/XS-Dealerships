-- Paste this into ox_inventory/data/items.lua, and copy
-- inventory_images/dealer_tablet.png into ox_inventory/web/images/.
--
-- The `client = { export = ... }` line is not optional. ox_inventory ignores
-- CreateUseableItem and only calls the export named here, so without it the
-- tablet does nothing when used.

['dealer_tablet'] = {
    label = 'Dealer Tablet',
    weight = 700,
    stack = false,
    close = true,
    description = 'Stock, orders, the business account and the team, wherever you are.',
    client = { export = 'XS-Dealerships.openTablet' },
},

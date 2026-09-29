Config = {}

-- Prints what the resource detected and why it refused things. Leave off on a live server.
Config.Debug = false

-- ── Who can use the creator ────────────────────────────────────────────────
-- /dealerships opens the creator. Any ONE of these is enough:
--   add_ace group.admin xs.dealerships allow        (in server.cfg)
--   a framework permission group listed in groups
--   a license listed in licenses (without the "license:" prefix)
Config.Admin = {
    command = 'dealerships',
    acePermission = 'xs.dealerships',
    groups = { 'god', 'admin' },
    licenses = {},
}

-- ── Other resources ────────────────────────────────────────────────────────
-- 'auto' finds whatever is running. Set a name to force one.
Config.Bridges = {
    framework = 'auto',   -- 'qbox' or 'qbcore'
    target = 'auto',      -- 'ox_target' or 'qb-target'

    -- Business accounts for job-run dealerships:
    -- 'Renewed-Banking', 'qb-banking', 'qb-management', 'okokBanking',
    -- 'tgg-banking', 'wasabi_banking', 'fd_banking', or 'none' to keep the
    -- dealership's money in its own ledger.
    banking = 'auto',

    -- Vehicle keys:
    -- 'qbx_vehiclekeys', 'qb-vehiclekeys', 'qs-vehiclekeys', 'wasabi_carlock',
    -- 'Renewed-Vehiclekeys', 'mk_vehiclekeys', 'cd_garage', 'okokGarage',
    -- 't1ger_keys', 'vehicles_keys', 'custom' or 'none'.
    -- 'custom' fires Config.CustomKeysEvent (see below) so any resource can hand keys out.
    keys = 'auto',

    -- Inventory, for the dealer tablet item: 'ox_inventory', 'qb-inventory',
    -- 'qs-inventory', 'ps-inventory', 'codem-inventory', 'core_inventory' or 'none'.
    inventory = 'auto',

    -- Fuel: 'ox_fuel', 'LegacyFuel', 'cdn-fuel', 'ps-fuel' or 'none'.
    -- Anything else built on LegacyFuel reads the tank the game itself keeps,
    -- which is set either way.
    fuel = 'auto',
}

-- Server event fired when keys = 'custom': TriggerEvent(name, source, plate, netId)
Config.CustomKeysEvent = ''

-- 'ox' uses ox_lib notifications, 'framework' uses Qbox/QBCore's own.
Config.Notify = {
    style = 'ox',
    position = 'top-right',
}

-- ── Dealership types ───────────────────────────────────────────────────────
-- Offered in the creator. `categories` are your framework's vehicle
-- categories, and decide which cars a new dealership of that type starts with.
-- Any car can still be added to any dealership by hand.
Config.Types = {
    { id = 'cars',     label = 'Cars',          blip = 326, categories = { 'compacts', 'sedans', 'suvs', 'coupes', 'muscle', 'sportsclassics', 'sports', 'offroad' } },
    { id = 'luxury',   label = 'Luxury',        blip = 523, categories = { 'super', 'sports' } },
    { id = 'bikes',    label = 'Motorcycles',   blip = 226, categories = { 'motorcycles', 'cycles' } },
    { id = 'trucks',   label = 'Trucks & vans', blip = 477, categories = { 'vans', 'commercial', 'industrial', 'utility' } },
    { id = 'boats',    label = 'Boats',         blip = 410, categories = { 'boats' } },
    { id = 'aircraft', label = 'Aircraft',      blip = 423, categories = { 'planes', 'helicopters' } },
}

-- ── Buying ─────────────────────────────────────────────────────────────────
Config.Purchase = {
    -- 'spawn'  the car comes out at the dealership's bought-car point, with keys.
    -- 'garage' the car goes straight into the garage below.
    deliver = 'spawn',
    garage = 'pillboxgarage',   -- one of YOUR garage names

    -- Put the buyer in the driver's seat when the car comes out.
    warpIntoVehicle = true,

    -- How customers can pay outright. Finance is set further down.
    cash = true,
    bank = true,

    -- Plate pattern for new cars: A = letter, 1 = digit, anything else is kept.
    -- Eight characters at most. Every plate is checked against every owned car.
    platePattern = '11AAA111',

    -- How close a player has to be to the desk or a showcase car to buy it.
    maxDistance = 12.0,
}

-- ── Paint ──────────────────────────────────────────────────────────────────
-- Picked on the buy screen. Cars are sold stock, so paint is the only choice.
Config.Paint = {
    secondary = true,      -- let buyers pick a second colour as well
    custom = true,         -- a free colour picker next to the swatches
    presets = {
        { label = 'Factory',        hex = false },
        { label = 'Jet black',      hex = '#0b0b0d' },
        { label = 'Graphite',       hex = '#3a3d42' },
        { label = 'Silver',         hex = '#b9bdc2' },
        { label = 'Frost white',    hex = '#f2f3f5' },
        { label = 'Torino red',     hex = '#b3121b' },
        { label = 'Candy orange',   hex = '#e8611a' },
        { label = 'Race yellow',    hex = '#f2c300' },
        { label = 'Racing green',   hex = '#0f4d2c' },
        { label = 'Mint',           hex = '#6fd6b0' },
        { label = 'Harbour blue',   hex = '#1d3f8f' },
        { label = 'Surf blue',      hex = '#2e8fd6' },
        { label = 'Midnight purple',hex = '#3b1f5c' },
        { label = 'Hot pink',       hex = '#e83e8c' },
        { label = 'Bronze',         hex = '#8a5a2b' },
        { label = 'Sand',           hex = '#c8b28a' },
    },
}

-- ── Showcase spots ─────────────────────────────────────────────────────────
Config.Showcase = {
    -- Display cars are only spawned for players this close, to spare the
    -- entity pool that every other resource shares.
    streamDistance = 70.0,

    -- A swapped car goes back to the spot's own car after this many minutes
    -- with nobody touching it. 0 keeps whatever was put there last.
    resetMinutes = 10,

    -- Plate text on display cars.
    plate = 'FOR SALE',
}

-- ── Sales desk ─────────────────────────────────────────────────────────────
Config.Desk = {
    -- A prop spawned on the desk point so players have something to walk up
    -- to. It is skipped when the map already has one within a metre.
    -- false for no prop.
    prop = 'prop_laptop_01a',
    radius = 1.2,
}

-- ── Test drives ────────────────────────────────────────────────────────────
Config.TestDrive = {
    enabled = true,       -- a dealership can still switch them off in the creator
    seconds = 90,
    -- Drive in a private copy of the world, so nobody else sees or hits the car.
    privateWorld = false,
    -- Put the driver back where they started when the time is up.
    returnToStart = true,
    plate = 'TESTDRV',
}

-- ── Finance ────────────────────────────────────────────────────────────────
-- A dealership can switch finance off in the creator.
Config.Finance = {
    enabled = true,
    downPayment = 20,     -- percent of the price paid up front, from the bank
    payments = 10,        -- number of payments after that
    interest = 10,        -- percent added to what is financed
    intervalHours = 24,   -- real-time hours between payments

    -- Payments come out of the bank on their own. A payment that cannot be
    -- taken counts as missed; this many in a row and the car is taken back.
    missedLimit = 3,

    -- Finance agreements a player can have open at once.
    maxActive = 2,

    -- What happens to a car when it is taken back:
    --   'remove'  gone from the player's garage for good.
    --   'hold'    the dealership keeps it. The player can pay what is left at
    --             the sales desk within holdDays to get it back in their garage.
    repossess = 'remove',
    holdDays = 7,

    -- Put a repossessed car back into its dealership's stock.
    returnToStock = true,
}

-- ── Job-run dealerships ────────────────────────────────────────────────────
-- A dealership bound to a job in the creator.
Config.Jobs = {
    -- Percent of the price paid to the salesperson who made the sale. A
    -- dealership can set its own in the creator. On a financed sale it comes
    -- out of the down payment.
    commission = 10,
    -- Optional per-grade commission: [grade] = percent
    gradeCommission = {},

    sellGrade = 0,        -- lowest grade that can sell to customers
    orderGrade = 1,       -- lowest grade that can order stock
    bossGrade = 3,        -- lowest grade that sees the account and the sales log
    requireDuty = true,   -- staff have to be on duty to do any of it

    -- How close a customer has to be for a salesperson to sell to them.
    sellDistance = 6.0,
    -- Seconds a customer has to answer a sale before it is withdrawn.
    offerSeconds = 60,
}

-- ── Dealer tablet ──────────────────────────────────────────────────────────
-- How staff of a job-run dealership run it: stock, ordering, the business
-- account, sales and the team, from anywhere. Paste the item from items/.
Config.Tablet = {
    -- The item that opens it. '' to use no item; staff then open the tablet
    -- from the sales desk instead.
    item = 'dealer_tablet',

    -- Hold a tablet prop while it is open.
    animation = true,
}

-- ── Stock ──────────────────────────────────────────────────────────────────
Config.Stock = {
    -- Starting stock for each car in a new job-run dealership. NPC dealerships
    -- start unlimited. Both can be changed per car in the creator.
    jobDefault = 3,

    -- Ordering more (job-run dealerships only): the business pays this percent
    -- of the sale price per car, and the order turns up after deliveryMinutes.
    wholesale = 70,
    deliveryMinutes = 30,
    maxPerOrder = 10,
    maxPendingOrders = 5,
}

-- ── Photos ─────────────────────────────────────────────────────────────────
-- Photos in the catalogue. A file in html/images/vehicles/<model>.png always
-- wins, so addon cars can have their own. Everything else uses this address,
-- where %s is the spawn name. false shows a drawn silhouette instead.
Config.Images = 'https://docs.fivem.net/vehicles/%s.webp'

-- Speed shown in the catalogue: 'mph' or 'kmh'.
Config.SpeedUnit = 'mph'

-- Money symbol shown in the catalogue.
Config.Currency = '$'

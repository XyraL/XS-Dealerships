<h1 align="center">XS-Dealerships</h1>

<p align="center">Dealerships you build in game, for <strong>QBox</strong> and <strong>QBCore</strong>. Run by nobody, or run by a job.</p>

<p align="center">
  <a href="https://github.com/XyraL/XS-Dealerships/releases"><img src="https://img.shields.io/github/v/release/XyraL/XS-Dealerships?style=flat-square&color=d6283a&label=release" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/framework-QBox%20%7C%20QBCore-55dcff?style=flat-square" alt="framework">
  <img src="https://img.shields.io/badge/price-free-30d158?style=flat-square" alt="price">
  <a href="https://xyralscripts.dev/docs-xs-dealerships"><img src="https://img.shields.io/badge/docs-xyralscripts.dev-a889ff?style=flat-square" alt="docs"></a>
  <a href="https://discord.gg/XRURAw4TM2"><img src="https://img.shields.io/badge/support-discord-5865F2?style=flat-square" alt="support"></a>
</p>

<p align="center">
  <a href="https://xyralscripts.dev/xs-dealerships">Website</a> &nbsp;·&nbsp;
  <a href="https://xyralscripts.dev/docs-xs-dealerships">Setup guide</a> &nbsp;·&nbsp;
  <a href="https://github.com/XyraL/XS-Dealerships/releases">Releases</a> &nbsp;·&nbsp;
  <a href="https://discord.gg/XRURAw4TM2">Discord</a>
</p>

<!-- SCREENSHOTS: drop 2-3 in-game shots here once captured -->

---

It ships **empty**. No dealerships of mine to delete and no coordinates from
someone else's map. Every dealership on your server is one you build with
`/dealerships`, where it stands.

## What it is

**A creator.** Make as many dealerships as you like. Each one has a type (cars,
luxury, motorcycles, trucks, boats, aircraft), a list of cars with their own
prices and stock, and four kinds of point you place in game:

- **Sales desk** — where people browse every car, buy, and pay their finance.
- **Showcase spots** — a car on display, as many as you want.
- **Where bought cars come out.**
- **Where test drives start.**

Each dealership is run by **nobody** — it just works — or by **a job**, and has
its own rules: who can buy, how people pay, the finance terms, how long a test
drive lasts, what staff can do and earn, and how fast ordered cars arrive. All
of it is set in the creator.

**The showroom.** Walk up to the desk or a car on display. Every car has its
window sticker: top speed, acceleration, braking and handling read from the
car itself, so addon cars show their own numbers. Pick a paint colour, pay with
cash, bank or finance, and you are put in the driver's seat of your new car
with its keys, a plate and a full tank. If something is parked where it comes
out, it goes straight to your garage instead.

Cars are sold stock. Paint is the only choice.

**Showcase spots.** Look at the car on the floor, buy it, test drive it, or swap
it for any other car the dealership sells. Everyone sees the swap, and the spot
goes back to its own car when nobody has touched it for a while. A test drive
puts you straight in the car.

**Finance.** A down payment, then payments that come out of the bank on their
own. Miss too many in a row and the dealership takes the car back — gone for
good, or held until the rest is paid. A payment that falls due while someone is
offline is taken when they are next on, after a few minutes to move money
around.

**Job-run dealerships.** Staff sell to the customer in front of them: they pick
the car, the customer picks the paint and how to pay, and the car comes out
with the keys while the salesperson gets their commission. Each dealership
decides whether customers can buy, swap the showcase cars and take test drives
on their own, or only through staff.

**The dealer tablet.** An item staff carry. The showroom floor, where they see
what every showcase spot is showing, change it, and sell any car to the
customer standing with them. Stock and ordering (paid from the business at a
wholesale price, delivered after a while), the business account with paying in
and taking out, every sale, and the team's sales and commission for the week.

## Requirements

- `qbx_core` or `qb-core`
- `ox_lib`
- `oxmysql`
- `ox_target` or `qb-target`

Everything else is found on its own:

| What | Works with |
| ---- | ---------- |
| Business accounts | Renewed-Banking, qb-banking, qb-management, okokBanking, tgg-banking, wasabi_banking, fd_banking — or the dealership keeps its own books |
| Vehicle keys | qbx_vehiclekeys, qb-vehiclekeys, qs-vehiclekeys, wasabi_carlock, Renewed-Vehiclekeys, mk_vehiclekeys, cd_garage, okokGarage, t1ger_keys, vehicles_keys, or your own event |
| Fuel | ox_fuel, LegacyFuel, cdn-fuel, ps-fuel |
| Garages | Qbox and QBCore garages, jg-advancedgarages, cd_garage |
| The tablet item | ox_inventory, qb-inventory, qs-inventory, ps-inventory, codem-inventory, core_inventory |

## Setup

### 1. Install it

Put `XS-Dealerships` in your resources and add it to your server.cfg after its
requirements:

```
ensure ox_lib
ensure oxmysql
ensure XS-Dealerships
```

The database sets itself up the first time it starts.

### 2. Add the dealer tablet

Paste the item from `items/ox_inventory.lua` (ox_inventory) or
`items/qb_core.lua` (everything else), and copy
`inventory_images/dealer_tablet.png` to your inventory's images folder:

| Inventory | Images folder |
| --------- | ------------- |
| ox_inventory | `web/images/` |
| qb-inventory, ps-inventory, qs-inventory | `html/images/` |
| codem-inventory | `html/itemimages/` |
| core_inventory | `html/img/` |

On ox_inventory the `client = { export = ... }` line is what makes the tablet
open. Leave it out and using the item does nothing.

Rather not have an item? Set `Config.Tablet.item = ''` and staff open the same
screen from the sales desk.

### 3. Give yourself the creator

```
add_ace group.admin xs.dealerships allow
```

Or list your framework's admin groups, or your license, in `Config.Admin`.
Without one of these, `/dealerships` only tells you that you are not allowed.

### 4. Build a dealership

Run `/dealerships` and press **New dealership**. The creator is a book with a
page for each part:

1. **Details** — the name, the type, who runs it, and the map blip.
2. **Selling** — whether customers can buy, swap and test drive on their own,
   cash and bank, where a bought car goes, the test drive length, and the plate
   on display cars.
3. **Finance** — the down payment, payments, interest, how often they come out,
   and what happens when someone stops paying. A worked example shows what a
   buyer would pay.
4. **Staff** (job-run only) — which grades sell, order stock and see the money,
   commission for each grade, and how ordering works.
5. **Points** — place the sales desk, the showcase spots, and where bought cars
   and test drives come out. You fly a camera to each spot, and vehicle points
   show the actual car so you can see it fits. Every other point shows as an
   outline while you place one, and turns red if they would hit.
6. **Cars** — add cars from your framework's vehicle list, or every car of the
   dealership's type at once. Set each price and how many are in stock. Leave
   stock blank for unlimited.

Then **Save**. Everyone on the server sees it straight away. Close the creator
whenever you like — nothing unsaved is lost.

Most of `config.lua` is only the starting point for a new dealership. Once it
is made, change it in the creator.

### 5. Job-run dealerships

Make the job in your framework first, then pick it in the creator. The Staff
page lists the job's own grades, so you pick who does what by name. Staff
order more cars from the tablet, and orders turn up after the time you set
there (5 minutes to start with).

## Photos

Every car that comes with the game has a photo. For an addon car, put a
`.png` named after its spawn name in `html/images/vehicles/`, and it is used
before anything else. Anything without a photo gets a drawn silhouette.

## Commands

| Command | Who | What |
| ------- | --- | ---- |
| `/dealerships` | Admins | Opens the creator |
| `/dealerdiag` | Anyone | Prints what the resource found — framework, banking, keys, inventory, your job — and where every dealership stands. Start here if something does not work |
| `/endtestdrive` | Anyone | Hands a test car back early |

## Your own keys resource

Set `Config.Bridges.keys = 'custom'` and `Config.CustomKeysEvent` to a server
event of yours. It gets `source, plate, netId` for every car handed over.

## License

Free to use on your own servers. No redistribution or resale. See `LICENSE`.

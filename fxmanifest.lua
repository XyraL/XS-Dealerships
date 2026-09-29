fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'XS-Dealerships'
author 'XyraL'
description 'Dealerships and a dealership creator for Qbox and QBCore: NPC or job-run, showcase cars, finance and stock orders.'
version '1.0.0'

dependencies {
    'ox_lib',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/util.lua',
}

client_scripts {
    'bridge/framework.lua',
    'bridge/target.lua',
    'bridge/keys.lua',
    'bridge/fuel.lua',
    'client/main.lua',
    'client/showcase.lua',
    'client/placement.lua',
    'client/ui.lua',
    'client/tablet.lua',
    'client/testdrive.lua',
    'client/creator.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/framework.lua',
    'bridge/banking.lua',
    'bridge/inventory.lua',
    'bridge/keys.lua',
    'server/db.lua',
    'server/showcase.lua',
    'server/store.lua',
    'server/vehicles.lua',
    'server/orders.lua',
    'server/finance.lua',
    'server/purchase.lua',
    'server/office.lua',
    'server/testdrive.lua',
    'server/tablet.lua',
    'server/creator.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/*.js',
    'html/images/vehicles/*',
}

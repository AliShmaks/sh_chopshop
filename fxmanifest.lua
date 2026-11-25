fx_version 'cerulean'
game 'gta5'

author 'SHARARAH'
description 'SHARARAH Advanced Chop Shop'
version '2.3.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/inventory.lua'
}

client_scripts {
    'client/state.lua',
    'client/helpers.lua',
    'client/parts.lua',
    'client/ui.lua',
    'client/audio.lua',
    'client/anims.lua',
    'client/tools.lua',
    'client/claim.lua',
    'client/chop.lua',
    'client/sell.lua',
    'client/cleanup.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/state.lua',
    'server/init.lua',
    'server/helpers.lua',
    'server/parts.lua',
    'server/tools.lua',
    'server/claim.lua',
    'server/chop.lua',
    'server/sell.lua',
    'server/sounds.lua',
    'server/cleanup.lua',
}

ui_page 'html/index.html'

files {
    'stream/*.ycd',
    'html/index.html',
    'html/audio.js',
    'html/sounds/*.ogg',
    'html/sounds/*.mp3',
    'html/sounds/*.wav',
    'html/sounds/*.mp4',
}

dependencies {
    'qb-core',
    'ox_lib',
    'ox_inventory',
    'oxmysql',
    'ox_target' 
}

lua54 'yes'
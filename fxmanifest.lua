fx_version 'cerulean'
game 'gta5'

name 'pen-restaurant'
description 'restaurant management'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'client/cl_*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_*.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/styles.css',
    'html/app.js'
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'qbx_core'
}

lua54 'yes'
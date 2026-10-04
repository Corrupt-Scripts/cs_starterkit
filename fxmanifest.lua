fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Corrupt Scripts'
description 'Gender-aware, one-time starter kit with NUI (QBox / QBCore)'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

dependencies {
    'oxmysql',
}

fx_version 'cerulean'
game 'gta5'

author 'RealRPG'
description 'RealRPG Futár Munka Rendszer - Komplett job skill, bónusz, kör és kézbesítés rendszer'
version '3.0.0'

ui_page 'html/index.html'

client_scripts {
    'config.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

-- Custom prop stream (prop_shop_locker)
data_file 'DLC_ITYP_REQUEST' 'stream/*.ytyp'

dependencies {
    'oxmysql'
}

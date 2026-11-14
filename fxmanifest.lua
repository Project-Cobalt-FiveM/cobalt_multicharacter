fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
name 'cobalt_multicharacter'
author 'Citgo'
description 'Multicharacter selection for Cobalt'
version '1.0.0'

dependencies {
    'ox_lib',
    'cobalt_mysql',
    'cobalt_core',
    'cobalt_weather',
    'illenium-appearance',
}

shared_script '@ox_lib/init.lua'

ox_libs { 'locale' }

client_script 'client/main.lua'
server_scripts {
    '@cobalt_mysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page '_nui/build/index.html'

files {
    '_nui/build/index.html',
    '_nui/build/assets/*',
    'config.lua',
    'client/scene.lua',
    'client/flight.lua',
    'client/arrival.lua',
    'client/geometry.lua',
    'data/nationalities.json',
    'locales/*.json',
}

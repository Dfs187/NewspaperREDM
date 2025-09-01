-- fxmanifest.lua (Lets Hope)
fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

author 'Dfs187'
description 'My first ever mod because i could not find any newspaper mods i liked'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/Store.html',
    'html/crafting.html',
    'html/submission.html',
    'html/ad_placement.html',
    'html/owner_dashboard.html',
    'html/owner_style.css',
    'html/owner_script.js',
    'html/images/*.jpg',
    'html/images/*.png'
}

shared_script 'config.lua'

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}
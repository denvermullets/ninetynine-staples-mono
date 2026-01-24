# Pin npm packages by running ./bin/importmap

pin 'application'
pin '@hotwired/turbo-rails', to: 'turbo.min.js'
pin '@hotwired/stimulus', to: 'stimulus.min.js'
pin '@hotwired/stimulus-loading', to: 'stimulus-loading.js'
pin_all_from 'app/javascript/controllers', under: 'controllers'

# we have to link to npm because there's a problem with it not getting the needed deps via importmaps
# @4.4.3 - 4.4.7 is latest at time of install
pin 'chart.js', to: 'https://ga.jspm.io/npm:chart.js@4.4.3/dist/chart.js'
# @0.3.2
pin '@kurkle/color', to: 'https://ga.jspm.io/npm:@kurkle/color@0.3.2/dist/color.esm.js'

# NOTE: Tesseract.js is loaded via script tag in card_scanner/show.html.erb
# because it needs to load worker files that don't work well with importmaps

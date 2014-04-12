
#
# This file is the default set of rules to compile a Pebble project.
#
# Feel free to customize this to your needs.
#

top = '.'
out = 'build'

import coffeescript
import glob

def options(ctx):
    ctx.load('pebble_sdk')

def configure(ctx):
    ctx.load('pebble_sdk')

def build(ctx):
    ctx.load('pebble_sdk')

    ctx.pbl_program(source=ctx.path.ant_glob('src/**/*.c'),
                    target='pebble-app.elf')

    with open('src/js/pebble-js-app.js', 'w') as output_file:
        files_in_dir = glob.glob('src/**/*.js')
        for file_in_dir in files_in_dir:
            if '/pebble-js-app.js' not in file_in_dir:
                with open(file_in_dir, 'r') as input_file:
                    output_file.write(input_file.read())

        files_in_dir = glob.glob('src/**/*.coffee')
        for file_in_dir in files_in_dir:
            with open(file_in_dir, 'r') as input_file:
                output_file.write(coffeescript.compile(input_file.read()))


    ctx.pbl_bundle(elf='pebble-app.elf',
                   js=ctx.path.ant_glob('src/js/**/*.js'))


#
# This file is the default set of rules to compile a Pebble project.
#
# Feel free to customize this to your needs.
#

import os.path

import glob
import coffeescript

top = '.'
out = 'build'

def options(ctx):
    ctx.load('pebble_sdk')

def configure(ctx):
    ctx.load('pebble_sdk')

def build(ctx):
    ctx.load('pebble_sdk')

    build_worker = os.path.exists('worker_src')
    binaries = []

    for p in ctx.env.TARGET_PLATFORMS:
        ctx.set_env(ctx.all_envs[p])
        ctx.set_group(ctx.env.PLATFORM_NAME)
        app_elf='{}/pebble-app.elf'.format(ctx.env.BUILD_DIR)
        ctx.pbl_program(source=ctx.path.ant_glob('src/**/*.c'),
        target=app_elf)

        if build_worker:
            worker_elf='{}/pebble-worker.elf'.format(ctx.env.BUILD_DIR)
            binaries.append({'platform': p, 'app_elf': app_elf, 'worker_elf': worker_elf})
            ctx.pbl_worker(source=ctx.path.ant_glob('worker_src/**/*.c'),
            target=worker_elf)
        else:
            binaries.append({'platform': p, 'app_elf': app_elf})


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

    ctx.set_group('bundle')
    ctx.pbl_bundle(binaries=binaries, js=ctx.path.ant_glob('src/js/**/*.js'))


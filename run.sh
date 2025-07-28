#!/bin/bash
npm run build:css
bundle exec jekyll serve --incremental --future --port 4003

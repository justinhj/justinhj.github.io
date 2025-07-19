#!/bin/bash
npm run build:css
bundle exec jekyll serve --incremental --port 4003

#!/bin/bash

service nginx start

bundle exec puma -C config/puma.rb

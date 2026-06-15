#!/bin/bash
exec /usr/bin/Xvfb :99 -screen 0 \
  "${SCREEN_WIDTH:-1920}x${SCREEN_HEIGHT:-1080}x${SCREEN_DEPTH:-24}"

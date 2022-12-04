#!/usr/bin/env bash

{
  docker-compose -f docker-compose.yml up -d
} || {
  sudo docker-compose -f docker-compose.yml up -d
}

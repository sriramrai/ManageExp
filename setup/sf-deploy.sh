#!/bin/bash

echo "Creating scratch org with alias 'Myhub'..."
sf org create scratch --definition-file config/project-scratch-def.json --alias MyHub --set-default --target-dev-hub sriram@rai.com --duration-days 30

echo "🔄 Deploying project to scratch org..."
sf project deploy start -a 62.0

echo "Assigning ExpenseManager permission sets to user..."
sf org assign permset --name ExpenseManager
#!/bin/bash
# Minimal user data for EKS managed node groups
# EKS automatically handles node bootstrap - only add custom configuration here

# Set environment variable
echo "Environment: ${environment}" >> /etc/environment
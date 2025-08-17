# Port Operations and Container Management System

A comprehensive blockchain-based system built with Clarity smart contracts for managing port operations, container tracking, and maritime logistics.

## Overview

This system provides a decentralized solution for port operations management, enabling transparent and efficient handling of container movements, berth scheduling, fee calculations, and customs documentation. Built on the Stacks blockchain using Clarity smart contracts.

## Key Features

### Container Tracking
- **End-to-End Visibility**: Track containers from origin port to final destination
- **Real-time Status Updates**: Live updates on container location and status
- **Multi-stakeholder Access**: Transparent information sharing across all parties
- **Immutable Records**: Blockchain-based audit trail for all container movements

### Port Operations Management
- **Berth Scheduling**: Automated berth allocation and scheduling system
- **Resource Management**: Efficient allocation of port resources and equipment
- **Vessel Management**: Track vessel arrivals, departures, and port activities
- **Operational Analytics**: Performance metrics and operational insights

### Financial Management
- **Demurrage Calculations**: Automated calculation of demurrage fees
- **Detention Tracking**: Monitor and calculate detention charges
- **Transparent Billing**: Clear, auditable fee structures
- **Multi-currency Support**: Handle various currencies and payment methods

### Customs and Documentation
- **Digital Documentation**: Automated trade document management
- **Customs Integration**: Streamlined customs clearance processes
- **Compliance Tracking**: Ensure regulatory compliance across jurisdictions
- **Document Verification**: Cryptographic verification of trade documents

## Smart Contract Architecture

The system consists of five interconnected Clarity smart contracts:

### 1. Container Contract (`container.clar`)
- Container registration and lifecycle management
- Status tracking and updates
- Ownership and custody chain management
- Container metadata and specifications

### 2. Port Operations Contract (`port-operations.clar`)
- Vessel arrival and departure management
- Port activity logging and tracking
- Operational status management
- Resource allocation coordination

### 3. Berth Management Contract (`berth-management.clar`)
- Berth availability and scheduling
- Reservation and allocation system
- Berth utilization tracking
- Scheduling conflict resolution

### 4. Fee Calculation Contract (`fee-calculation.clar`)
- Demurrage and detention fee calculations
- Dynamic pricing based on port conditions
- Fee payment tracking and verification
- Multi-party fee distribution

### 5. Documentation Contract (`documentation.clar`)
- Trade document storage and management
- Document verification and authentication
- Customs clearance status tracking
- Regulatory compliance monitoring

## Data Types and Structures

### Container Data
```clarity
{
  container-id: (string-ascii 20),
  owner: principal,
  current-location: (string-ascii 50),
  status: (string-ascii 20),
  cargo-type: (string-ascii 30),
  weight: uint,
  destination: (string-ascii 50),
  created-at: uint,
  updated-at: uint
}

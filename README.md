# Fleet Supply Management

A responsive prototype for managing fleet vehicle supply requests at a police station.

## Sections

- First aid supplies
- Vehicle equipment
- Vehicle maintenance

## Current features

- Submit resupply requests from phone or desktop
- View a live request dashboard
- Filter by request status
- Search by item, vehicle, requester, or notes
- Warn users when an item has already been requested recently
- Supervisor mode for changing status or deleting requests

## Request statuses

- Request made
- Request ordered
- Delivered
- Cancelled

## Demo supervisor access

The current prototype uses a simple local access code for demonstration only.

Demo code: `1976`

For real operational use, replace this with proper user accounts, authentication, and a shared database.

## Data note

This first version stores requests in the browser on the device using local storage. That means requests are not yet shared between different phones or computers. The next production step would be adding a backend database and secure login.

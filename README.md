# Firestore to CSV Exporter

This script exports your Firestore data to CSV files. Each collection in your Firestore database will be exported to a separate CSV file.

## Prerequisites

1. Python 3.7 or higher
2. Google Cloud project with Firestore enabled
3. Proper authentication set up (either default credentials or a service account)

## Setup

1. Install the required dependencies:
```bash
pip install -r requirements.txt
```

2. Authentication:
   - Option 1: Use Application Default Credentials
     ```bash
     gcloud auth application-default login
     ```
   - Option 2: Use a service account
     - Download your service account key file from the Google Cloud Console
     - Rename it to `serviceAccount.json` and place it in the same directory as the script

## Usage

Simply run the script:
```bash
python firestore_to_csv.py
```

The script will:
1. Export all your Firestore data to a Cloud Storage bucket
2. Download the exported data
3. Convert each collection to a separate CSV file

## Output

- Each collection will be saved as a separate CSV file named `{collection_name}.csv`
- The CSV files will include all fields from all documents in the collection
- Documents with missing fields will have empty values for those fields
- Arrays and maps will be stored as JSON strings

## Notes

- Make sure you have sufficient permissions in your Google Cloud project
- The script requires the following roles:
  - `Cloud Datastore Import Export Admin`
  - `Storage Object Viewer`
- Large collections may take some time to export
- The script handles nested data structures by converting them to JSON strings

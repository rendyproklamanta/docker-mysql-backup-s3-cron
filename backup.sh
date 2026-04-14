#!/bin/bash

# Set variables
BACKUP_DIR="${BACKUP_DIR}"
DELETE_OLDER_THAN_DAY=${DELETE_OLDER_THAN_DAY}
CURRENT_TIMESTAMP=$(date +%s)

# Ensure we're in the backup directory
cd "$BACKUP_DIR" || exit 1

echo "Starting MySQL backup upload to S3..."

# Upload all latest.*.sql.gz files to S3
for backup_file in latest.*.sql.gz; do
    if [ -f "$backup_file" ]; then
        echo "Uploading $backup_file to S3..."
        aws s3 cp "$backup_file" "$S3_BUCKET/" --endpoint-url "$ENDPOINT_URL"
    fi
done

echo "Cleaning old backups from S3 (older than $DELETE_OLDER_THAN_DAY days)..."

# Get list of all files in S3 bucket
aws s3 ls "$S3_BUCKET/" --endpoint-url "$ENDPOINT_URL" | while read -r line; do
    file_date=$(echo "$line" | awk '{print $1" "$2}')
    file_name=$(echo "$line" | awk '{print $4}')
    
    # Skip if file_name is empty
    if [ -z "$file_name" ]; then
        continue
    fi
    
    # Skip latest.*.sql.gz files (keep only timestamped backups for deletion)
    if [[ $file_name == latest.* ]]; then
        continue
    fi
    
    # Parse file date and convert to seconds
    file_timestamp=$(date -d "$file_date" +%s 2>/dev/null)
    
    # Calculate age of file in seconds and convert to days
    age=$(( (CURRENT_TIMESTAMP - file_timestamp) / 86400 ))

    # Delete file if older than retention days
    if [ "$age" -gt "$DELETE_OLDER_THAN_DAY" ]; then
        echo "Deleting $file_name from S3 (Age: $age days)"
        aws s3 rm "$S3_BUCKET/$file_name" --endpoint-url "$ENDPOINT_URL"
    fi
done

echo "Backup completed successfully!"
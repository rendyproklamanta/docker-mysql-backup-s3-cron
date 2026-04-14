#!/bin/bash

# Set variables
DATE=$(date +%Y%m%d%H%M%S)
BACKUP_DIR="${BACKUP_DIR}"
DELETE_OLDER_THAN_DAY=${DELETE_OLDER_THAN_DAY}
CURRENT_TIMESTAMP=$(date +%s)

# Ensure we're in the backup directory
cd "$BACKUP_DIR" || exit 1

echo "Starting MySQL backup upload to S3..."

# Upload all latest.*.sql.gz files to S3 with timestamp
for backup_file in latest.*.sql.gz; do
    if [ -f "$backup_file" ]; then
        # Extract database name from latest.*.sql.gz
        db_name=$(echo "$backup_file" | sed 's/^latest\.//' | sed 's/\.sql\.gz$//')
        
        # Create timestamped filename: dbname.YYYYMMDDHHmmss.sql.gz
        timestamped_file="${db_name}.${DATE}.sql.gz"
        
        # Create S3 path per database: bucket/dbname/
        s3_db_path="$S3_BUCKET/${db_name}"
        
        echo "Uploading $timestamped_file to S3: $s3_db_path"
        aws s3 cp "$backup_file" "$s3_db_path/$timestamped_file" --endpoint-url "$ENDPOINT_URL"
    fi
done

echo "Cleaning old backups from S3 (older than $DELETE_OLDER_THAN_DAY days)..."

# Get list of database directories in S3
aws s3 ls "$S3_BUCKET/" --endpoint-url "$ENDPOINT_URL" | while read -r line; do
    dir_name=$(echo "$line" | awk '{print $2}' | sed 's/\/$//')
    
    # Skip if empty
    if [ -z "$dir_name" ]; then
        continue
    fi
    
    # List files in each database directory
    aws s3 ls "$S3_BUCKET/$dir_name/" --endpoint-url "$ENDPOINT_URL" | while read -r file_line; do
        file_date=$(echo "$file_line" | awk '{print $1" "$2}')
        file_name=$(echo "$file_line" | awk '{print $4}')
        
        # Skip if file_name is empty
        if [ -z "$file_name" ]; then
            continue
        fi
        
        # Skip if not a timestamped backup (dbname.YYYYMMDDHHmmss.sql.gz)
        if ! [[ $file_name =~ \.[0-9]{14}\.sql\.gz$ ]]; then
            continue
        fi
        
        # Parse file date and convert to seconds
        file_timestamp=$(date -d "$file_date" +%s 2>/dev/null)
        
        # Calculate age of file in seconds and convert to days
        age=$(( (CURRENT_TIMESTAMP - file_timestamp) / 86400 ))

        # Delete file if older than retention days
        if [ "$age" -gt "$DELETE_OLDER_THAN_DAY" ]; then
            echo "Deleting $file_name from S3 (Age: $age days)"
            aws s3 rm "$S3_BUCKET/$dir_name/$file_name" --endpoint-url "$ENDPOINT_URL"
        fi
    done
done

echo "Backup completed successfully!"
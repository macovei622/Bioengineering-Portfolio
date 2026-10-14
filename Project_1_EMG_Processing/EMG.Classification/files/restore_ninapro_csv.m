function restore_ninapro_csv()
% Rebuild the original CSV by concatenating its byte-for-byte chunks.

parts = dir('Ninapro_DB1.csv.part*');
if isempty(parts)
    error('restore_ninapro_csv:NoParts', ...
        'No Ninapro_DB1.csv.part* files were found in the current folder.');
end

[~, order] = sort({parts.name});
parts = parts(order);

output_id = fopen('Ninapro_DB1.csv', 'wb');
if output_id == -1
    error('restore_ninapro_csv:OpenOutputFailed', ...
        'Could not create Ninapro_DB1.csv in the current folder.');
end
output_cleanup = onCleanup(@() fclose(output_id));

for part_index = 1:numel(parts)
    input_id = fopen(parts(part_index).name, 'rb');
    if input_id == -1
        error('restore_ninapro_csv:OpenPartFailed', ...
            'Could not open %s.', parts(part_index).name);
    end
    input_cleanup = onCleanup(@() fclose(input_id));

    while true
        [bytes, count] = fread(input_id, 1024 * 1024, '*uint8');
        if count == 0
            [message, error_number] = ferror(input_id);
            if error_number ~= 0
                error('restore_ninapro_csv:ReadFailed', ...
                    'Could not read %s: %s', parts(part_index).name, message);
            end
            break;
        end

        written = fwrite(output_id, bytes, 'uint8');
        if written ~= count
            error('restore_ninapro_csv:WriteFailed', ...
                'Could not write the complete contents of %s.', ...
                parts(part_index).name);
        end
    end

    clear input_cleanup
end

clear output_cleanup
end

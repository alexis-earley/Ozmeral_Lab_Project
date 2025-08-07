% function sFiles = Step4_New(sFiles, TableName) 


%{
% Process: Select file paths with tag: notch_
sFiles = bst_process('CallProcess', 'process_select_tag', sFiles, [], ...
    'tag',    'notch_', ...
    'search', 1, ...  % Search the file paths
    'select', 1);  % Select only the files with the tag

%}

TableName = 'OHI_File_Name_Table.csv';
FullTable = (table2cell(readtable(TableName, 'Delimiter', ',')));

Subjs = FullTable(:,1);
tFileNames = FullTable(:,2);
Aids = FullTable(:,3);
Conditions = FullTable(:,4);
Dirs = FullTable(:,5);

sFileNames = {};

for i = 1:length(sFiles)
    sFile = sFiles(i);
    sFileName = sFile.Condition;
    sFileName = sFileName(5:end);
    sFileNames{end + 1} = sFileName;
end

%testing = (ismember(tFileNames, sFileName) == 0);


[~ , sFileIndxs] = ismember(sFileNames, tFileNames);


for j = 1:length(sFileIndxs)

    sFileIndx = sFileIndxs(j);

    if sFileIndx > 0
        currFile = sFiles(sFileIndx);

        Subj = Subjs(sFileIndx);
        tFileName = tFileNames(sFileIndx);
        Aid = Aids(sFileIndx);
        Condition = Conditions(sFileIndx);
        Dir = Dirs(sFIleIndx);

        FolderName = strcat(Aid, '_', Condition, '_', Dir, '_');

        % RENAME FILE

        % MOVE FOLDER

        % Process: Import MEG/EEG: Events
        CurrFile = bst_process('CallProcess', 'process_import_data_event', CurrFile, [], ...
            'subjectname',   SubjName, ...
            'condition',     Name, ...
            'eventname',     '1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,50,60,1_N,2_N,3_N,4_N,5_N,6_N,7_N,8_N,9_N,10_N,11_N,12_N,13_N,14_N,15_N,16_N,17_N,18_N,19_N,20_N,21_N,22_N,23_N,24_N,25_N,1_Y,2_Y,3_Y,4_Y,5_Y,6_Y,7_Y,8_Y,9_Y,10_Y,11_Y,12_Y,13_Y,14_Y,15_Y,16_Y,17_Y,18_Y,19_Y,20_Y,21_Y,22_Y,23_Y,24_Y,25_Y', ...
            'timewindow',    [], ...
            'epochtime',     [-0.1, 2], ...
            'createcond',    0, ...
            'ignoreshort',   1, ...
            'usectfcomp',    1, ...
            'usessp',        1, ...
            'freq',          [], ...
            'baseline',      [-0.1, -0.002], ...
            'blsensortypes', 'EEG');
    
        % Process: Remove linear trend: [-100ms,2000ms]
        CurrFile = bst_process('CallProcess', 'process_detrend', CurrFile, [], ...
            'timewindow',  [-0.1, 2], ...
            'sensortypes', 'EEG', ...
            'overwrite',   1);

        %
    end
end


%k = find(x==13)

%{
for j = 1:length(tFileNames)

    tFileName = tFileNames(j)
    indx = (find(ismember(sFileNames, tFileName)) == 1)






end

%}
% end
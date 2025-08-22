function Step5OHI(sFiles, protocol_path)

% If needed, make folder
if ~exist(protocol_path, 'dir')
    mkdir(protocol_path);
end

% Initialize the structure that will hold all exported data
currStruct = struct();

for i = 1:length(sFiles)

    sFile = sFiles(i);

    fullCondition = sFile.Condition; % Old file name, ex. 'Epochs_EOR21_Aim1_1372_2021-09-07_14-10-20_band_notch_11_UltraZoom_PassiveN'
    if iscell(fullCondition) 
        fullCondition = fullCondition{1};
    end
    fullCondition = char(fullCondition); % Convert to char array

    sections = strsplit(fullCondition, '_'); % Seperate based on underscores
    notchLogical = strcmp(sections, 'notch'); % Writes true only for notch section, false otherwise
    notchIdx = find(notchLogical); % Get notch index
    fileNameSecs = sections(2:notchIdx + 1); % Go from epochs to notch_#
    fileName = strjoin(fileNameSecs, '_'); % Put sections back together
    fileName = strrep(fileName, '-', '_'); % Put underscores instead of dashes so MATLAB doesn't get mad about the name

    stateName = sections{notchIdx + 2}; % Says whether trial was Unaided, Omni, or UltraZoom
    % state is a MATLAB keyword in some packages
    trialCondition = matlab.lang.makeValidName(sections{notchIdx + 3}); % PassiveQ, PassiveN, Attend30L, or Attend60

    rawComment = sFiles(i).Comment; % Example: '1N (#6) | detrend'
    if iscell(rawComment)
        rawComment = rawComment{1}; 
    end
    triggerNum = extractBefore(rawComment, ' ');
    triggerName = ['trigger_', triggerNum]; % Ex. trigger_1N

    subject = sFile.SubjectName; % Subject name
    if iscell(subject)
        subject = subject{1}; 
    end
    
    try
        matlabData = in_bst_data(sFile.FileName);
    catch ME
        warning(['Skipping file #', num2str(i), ' due to error:']);
        warning(getReport(ME, 'basic'));
        continue; % Skip this iteration and move to the next file
    end

    F = matlabData.F; % Get F field that holds the files

    % Initialize nested struct if needed
    if ~isfield(currStruct, stateName)
        currStruct.(stateName) = struct(); % One struct per state
    end
    stateStruct = currStruct.(stateName);

    if ~isfield(stateStruct, subject)
        stateStruct.(subject) = struct(); % Add subject to state struct
    end
    subjLevel = stateStruct.(subject);

    if ~isfield(subjLevel, trialCondition)
        subjLevel.(trialCondition) = struct(); % Add trial to struct reference, if needed
    end

    if ~isfield(subjLevel.(trialCondition), triggerName)
        subjLevel.(trialCondition).(triggerName) = struct(); % Add trigger to struct reference, if needed
    end

    if ~isfield(subjLevel.(trialCondition).(triggerName), fileName)
        subjLevel.(trialCondition).(triggerName).(fileName) = struct(); % Add file name to struct reference, if needed
    end

    fileStruct = subjLevel.(trialCondition).(triggerName).(fileName);
    numEpochs = length(fieldnames(fileStruct)); % Already this many epochs in strut
    epochNum = numEpochs + 1; % Pick next value to create tag
    epochTag = ['epoch_', num2str(epochNum)]; 

    subjLevel.(trialCondition).(triggerName).(fileName).(epochTag) = F;
    stateStruct.(subject) = subjLevel;
    currStruct.(stateName) = stateStruct;

    if mod(i,1000) == 0
        disp(['Added file #', num2str(i)]);
    end

    %disp(['Added file #', num2str(i)]);

    %{
    disp(['Subject: ', subject]);
    disp(['State: ', stateName])
    disp(['TrialCondition: ', trialCondition]); 
    disp(['Trigger: ', triggerName]);
    disp(['FileName: ', fileName]);
    disp(['EpochTag: ', epochTag]);
    fprintf('\n');
    %}

end

% Save files by STATE and then SUBJECT
disp('Saving to protocol paths.')
stateNames = fieldnames(currStruct);
for s = 1:length(stateNames)
    stateName = stateNames{s};
    stateFolder = fullfile(protocol_path, stateName);
    if ~exist(stateFolder, 'dir')
        mkdir(stateFolder);
    end

    stateStruct = currStruct.(stateName);
    subjectNames = fieldnames(stateStruct);
    for i = 1:length(subjectNames)
        subjectName = subjectNames{i};
        savePath = fullfile(stateFolder, [subjectName, '.mat']);
        save(savePath, '-struct', 'stateStruct', subjectName, '-v7.3');
        disp(['Saved: ', savePath])
    end
end

end


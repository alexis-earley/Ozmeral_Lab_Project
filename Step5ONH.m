function Step5ONH(sFiles, protocol_path, leftSubjs, rightSubjs)

% Ex. Step5ONH(sFiles, 'E:\Alexis_Brainstorm\EOR21_Earley_Paper_Final\ONH_Data_Structs\Test_Step_6A_Input',
% {'1009', '1157', '1145', '1068', '1273', '1228', '1081', '1223', '1071'}, 
% {'0170', '1153', '1031', '1263', '1264', '1113', '1191', '1111', '1337'})

% If needed, make folder
if ~exist(protocol_path, 'dir')
    mkdir(protocol_path);
end

% Initialize the structure that will hold all exported data
currStruct = struct();

for i = 1:length(sFiles)

    if mod(i,1000) == 0
        disp(['Adding file #', num2str(i)]);
    end

    sFile = sFiles(i);

    fullCondition = sFile.Condition; % Old file name, ex. 'Epochs_EOR21_Aim1_1372_2021-09-07_14-10-20_band_notch_11_UltraZoom_PassiveN'
    if iscell(fullCondition) 
        fullCondition = fullCondition{1};
    end
    fullCondition = char(fullCondition); % Convert to char array

    sections = strsplit(fullCondition, '_'); % Seperate based on underscores

    % NEW FOR ONH 
    block = sections{1}; % Ex. Block 1
    iteration = sections{2}; % Ex. 1
    fileName = [block, '_', iteration];

    noiseLevel = sections{3}; % Ex. Noise or Quiet
    location = sections{4}; % Ex. Attend60 or Attend30 or Passive

    subject = sFile.SubjectName; % Subject name
    if iscell(subject)
        subject = subject{1}; 
    end

    subjSects = strsplit(subject, '_'); % Seperate based on underscores
    subNum = subjSects{2};
    isInLeft = ismember(subNum, leftSubjs);
    isInRight = ismember(subNum, rightSubjs);

    if strcmp(location, 'Passive')
        isPassive = true;
    else 
        isPassive = false;
    end

    if isPassive 
        if strcmp(noiseLevel, 'Quiet')
            trialCondition = 'PassiveQ';
        elseif strcmp(noiseLevel, 'Noise')
            trialCondition = 'PassiveN';
        end

    else % is Active
        if isInLeft
            trialCondition = [location, 'L'];
        elseif isInRight
            trialCondition = [location, 'R'];
        elseif isInLeft && isInRight
            error(['Subject_', subNum, ' is listed as in both the left and right groups.'])
        else
            error(['Subject_', subNum, ' is listed as in neither the left or right groups.'])
        end
    end

    stateName = 'Unaided';
    
    rawComment = sFiles(i).Comment; % Example: '1N (#6) | detrend'
    if iscell(rawComment)
        rawComment = rawComment{1}; 
    end
    triggerNum = extractBefore(rawComment, ' ');

    if ~isPassive
        if ~(endsWith(triggerNum, 'N') || endsWith(triggerNum, 'Y'))
            continue;
        end
    end

    triggerName = ['trigger_', triggerNum]; % Ex. trigger_1N

    matlabData = in_bst_data(sFile.FileName);
    badChanIndices = find(matlabData.ChannelFlag == -1); % THIS IS WORKING 
    if isfield(matlabData, 'BadSegment') && matlabData.BadSegment
        continue;
    end
    F = matlabData.F; % Get F field that holds the files

    nRows = size(F, 1);
    if nRows == 70 || nRows == 88
        for i = 1:length(badChanIndices)
            idx = badChanIndices(i);
            if idx ~= 32 && idx < 65
                disp(['Unexpected bad channel at index ', num2str(idx), ...
                      ' in file: ', sFile.FileName]);
            end
        end
    elseif nRows == 69
        for i = 1:length(badChanIndices)
            idx = badChanIndices(i);
            if idx < 64
                disp(['Unexpected bad channel at index ', num2str(idx), ...
                      ' in file: ', sFile.FileName]);
            end
        end
    end

    % Set bad channel rows to NaN
    F(badChanIndices, :) = NaN;

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

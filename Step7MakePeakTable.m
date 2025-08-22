function Step7MakePeakTable(inputDir, outputDir, timeRanges)

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

fs = 500;
tMin = -0.1;
cutoff = 30; % LPF cutoff

% Filter coefficients for LPF
[b, a] = butter(4, cutoff / (fs / 2), 'low');

files = dir(fullfile(inputDir, '*.mat'));
if isempty(files)
    error(['No .mat files found in ', inputDir]);
end

% Load first file to get condition names
sampleFile = load(fullfile(inputDir, files(1).name));
rootName = fieldnames(sampleFile);
subjStruct = sampleFile.(rootName{1});
condNames = fieldnames(subjStruct);

% Create time vector based on size of EEG matrix
firstData = subjStruct.(condNames{1}).epoch_avg;
nSamples = size(firstData, 2);
timeVec = linspace(tMin, tMin + (nSamples-1)/fs, nSamples) * 1000;

subjectIDs = cell(length(files), 1); % To hold subject names without tags
peakData = cell(length(files), 1); % Holds subject structs

for f = 1:length(files)
    disp(['Processing subject ', num2str(f), ' of ', num2str(length(files))]);

    % Extract subject name without tag
    parts = split(files(f).name, '-');
    if numel(parts) >= 2
        subjectIDs{f} = parts{1};
    else
        subjectIDs{f} = erase(files(f).name, '.mat');
    end

    % Load file
    filePath = fullfile(inputDir, files(f).name);
    data = load(filePath);
    fNames = fieldnames(data);
    subjStruct = data.(fNames{1});

    subjPeaks = struct(); % Subject struct with peak data

    for c = 1:length(condNames)
        condName = condNames{c};
        epochAvg = subjStruct.(condName).epoch_avg;

        GFP = std(epochAvg, 0, 1) * 1e6; % Get GFP in microvolts
        GFP_filt = filtfilt(b, a, GFP); % LPF

        for timeIdx = 1:size(timeRanges, 1)
            tStart = timeRanges(timeIdx,1);
            tEnd = timeRanges(timeIdx,2);
            idxRange = find(timeVec >= tStart & timeVec <= tEnd); % Get indices in range
            [peakVal, peakIdx] = max(GFP_filt(idxRange)); % Max amplitude in range
            peakLat = timeVec(idxRange(1) + peakIdx - 1); % Time where peak occurred

            subjPeaks.(condName)(timeIdx).amp = peakVal;
            subjPeaks.(condName)(timeIdx).lat = peakLat;
        end
    end

    peakData{f} = subjPeaks;
end

% Table variable headers
tableVars = {'Subject'};
tableData = subjectIDs;
numericTable = []; % Store numeric data only

% Build data columns for each condition and time window
for c = 1:length(condNames)
    cond = condNames{c};

    % Add column names for early/mid/late windows
    colNames = {
        [cond '_Early_Amplitude'], ...
        [cond '_Early_Latency'], ...
        [cond '_Middle_Amplitude'], ...
        [cond '_Middle_Latency'], ...
        [cond '_Late_Amplitude'], ...
        [cond '_Late_Latency']
    };
    tableVars = [tableVars, colNames];

    ampsEarly = zeros(length(files), 1);
    latsEarly = zeros(length(files), 1);
    ampsMid = zeros(length(files), 1);
    latsMid = zeros(length(files), 1);
    ampsLate = zeros(length(files), 1);
    latsLate = zeros(length(files), 1);

    for f = 1:length(files)
        subjPeaks = peakData{f}.(cond);

        ampsEarly(f) = subjPeaks(1).amp;
        latsEarly(f) = subjPeaks(1).lat;
        ampsMid(f) = subjPeaks(2).amp;
        latsMid(f) = subjPeaks(2).lat;
        ampsLate(f) = subjPeaks(3).amp;
        latsLate(f) = subjPeaks(3).lat;
    end

    tableData = [tableData, ...
        num2cell(ampsEarly), num2cell(latsEarly), ...
        num2cell(ampsMid), num2cell(latsMid), ...
        num2cell(ampsLate), num2cell(latsLate)];

    numericTable = [numericTable, ...
        ampsEarly, latsEarly, ...
        ampsMid, latsMid, ...
        ampsLate, latsLate];
end

% Add row of averages
averageRow = [{'Average'}];
for col = 1:size(numericTable, 2)
    avgVal = mean(numericTable(:, col), 'omitnan');
    averageRow{end+1} = avgVal;
end
tableData = [tableData; averageRow];

% Convert to table
peakTable = cell2table(tableData, 'VariableNames', tableVars);

% Save final CSV
writetable(peakTable, fullfile(outputDir, 'PeakTable.csv'));
disp(['Saved peak table to ', outputDir]);
end
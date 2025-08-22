function Step7GraphGFPAllSubjects2(inputDir, outputDir, timeRanges, maxTime)

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

fs = 500;
tMin = -0.1;

files = dir(fullfile(inputDir, '*.mat'));
if isempty(files)
    error(['No .mat files found in ', inputDir]);
end

% Load first file to determine times
sampleFile = load(fullfile(inputDir, files(1).name));
rootName = fieldnames(sampleFile);
condNames = fieldnames(sampleFile.(rootName{1}));
firstData = sampleFile.(rootName{1}).(condNames{1}).epoch_avg;
nSamples = size(firstData, 2);
timeVec = linspace(tMin, tMin + (nSamples-1)/fs, nSamples) * 1000;

lastIndex = find(timeVec <= maxTime * 1000, 1, 'last');
ts = timeVec(1:lastIndex);

% Create LPF for final-only use
cutoff = 30; 
[b, a] = butter(4, cutoff / (fs / 2), 'low');

% Extract subject IDs
subjectIDs = cell(length(files), 1);
for f = 1:length(files)
    parts = split(files(f).name, '-');
    id = parts{1};
    id = erase(id, '_6F'); % Remove tag from label
    subjectIDs{f} = id;
end

allGFP = struct();      % per-subject GFP (UNFILTERED)
allPeaks = struct();    % per-subject peak vals and latencies (computed on unfiltered GFP here)
maxGFPAmp = struct();   % track max GFP amplitude per condition across subjects (unfiltered)

% Preallocate per condition with NaNs (so missing subjects don't become zeros)
for c = 1:length(condNames)
    cond = condNames{c};
    allGFP.(cond) = nan(length(files), lastIndex);
end

for f = 1:length(files)
    data = load(fullfile(inputDir, files(f).name));
    rootName = fieldnames(data);
    subjStruct = data.(rootName{1});

    for c = 1:length(condNames)
        cond = condNames{c};
        if isfield(subjStruct, cond) && isfield(subjStruct.(cond), 'epoch_avg')
            epoch_avg = subjStruct.(cond).epoch_avg(:, 1:lastIndex);
            GFP = std(epoch_avg, 0, 1) * 1e6; % Convert to microvolts (unfiltered)
            allGFP.(cond)(f, :) = GFP;

            % Per-subject peaks from unfiltered GFP (if you prefer filtered here, swap to filtfilt(b,a,GFP))
            for r = 1:size(timeRanges, 1)
                tStart = timeRanges(r, 1);
                tEnd = timeRanges(r, 2);
                idxRange = find(ts >= tStart & ts <= tEnd);
                [peakVal, peakIdx] = max(GFP(idxRange));
                peakLat = ts(idxRange(1) + peakIdx - 1);
                allPeaks.(cond)(f, r).val = peakVal;
                allPeaks.(cond)(f, r).lat = peakLat;
            end

            if ~isfield(maxGFPAmp, cond)
                maxGFPAmp.(cond) = max(GFP);
            else
                maxGFPAmp.(cond) = max(maxGFPAmp.(cond), max(GFP));
            end
        end
    end
end

% Loop through each condition and create figures
for c = 1:length(condNames)
    cond = condNames{c};
    for peakFlag = [true, false]
        if peakFlag
            figTag = 'WithPeaks';
        else
            figTag = 'NoPeaks';
        end

        % Valid subjects are non-NaN rows
        validMask = ~all(isnan(allGFP.(cond)), 2);
        nSubjects = sum(validMask);
        totalPlots = nSubjects + 1; % Include one for average
        nCols = ceil(sqrt(totalPlots));
        nRows = ceil(totalPlots / nCols);

        figure('Visible', 'off', 'Position', [100 100 1400 800]); % Hide figure while plotting

        % Plot each valid subject
        vIdx = find(validMask);
        for k = 1:nSubjects
            fidx = vIdx(k);
            subplot(nRows, nCols, k);
            plot(ts, allGFP.(cond)(fidx, :), 'k', 'LineWidth', 1);
            hold on;

            if peakFlag && isfield(allPeaks, cond) && numel(allPeaks.(cond)) >= fidx
                peakColors = {'r', 'g', 'b'};
                for r = 1:size(timeRanges, 1)
                    if ~isempty(allPeaks.(cond)(fidx, r).lat)
                        peakLat = allPeaks.(cond)(fidx, r).lat;
                        peakVal = allPeaks.(cond)(fidx, r).val;
                        plot(peakLat, peakVal, 'x', 'Color', peakColors{r}, 'MarkerSize', 8, 'LineWidth', 1.5);
                    end
                end
            end

            title(subjectIDs{fidx}, 'Interpreter', 'none', 'FontSize', 8);
            xlim([min(ts), max(ts)]);
            if k > (nRows - 1) * nCols
                xlabel('Time (ms)'); 
            end
            if mod(k - 1, nCols) == 0
                ylabel('GFP (\muV)'); 
            end
        end

        % Plot grand-average trace (compute mean across subjects, then filter ONCE)
        subplot(nRows, nCols, totalPlots);
        meanGFP_unfilt = mean(allGFP.(cond), 1, 'omitnan');
        meanGFP = filtfilt(b, a, meanGFP_unfilt); % final-only filter
        plot(ts, meanGFP, 'k', 'LineWidth', 1.5);
        hold on;

        peakText = cell(1, size(timeRanges, 1));
        peakColors = {'r', 'g', 'b'};
        for r = 1:size(timeRanges, 1)
            tStart = timeRanges(r, 1);
            tEnd = timeRanges(r, 2);
            idxRange = find(ts >= tStart & ts <= tEnd);
            [peakVal, peakIdx] = max(meanGFP(idxRange));
            peakLat = ts(idxRange(1) + peakIdx - 1);
            if peakFlag
                plot(peakLat, peakVal, 'x', 'Color', peakColors{r}, 'MarkerSize', 8, 'LineWidth', 1.5);
            end
            peakText{r} = [num2str(tStart), '-', num2str(tEnd), ' ms: ', num2str(peakVal, '%.2f'), ' uV'];
        end

        title({'Average GFP (final-only filtered)', peakText{:}}, 'FontSize', 8, 'Interpreter', 'none');
        % Use max of subjects or of mean to set ylim comfortably
        ymax = max([maxGFPAmp.(cond), max(meanGFP)]);
        ylim([0 ymax * 1.1]);
        xlim([min(ts) max(ts)]);
        xlabel('Time (ms)'); ylabel('GFP (\muV)');

        sgtitle(['GFP per Subject - ', cond, ' (', figTag, ')'], 'Interpreter', 'none');
        saveas(gcf, fullfile(outputDir, ['Step7GraphGFP_', cond, '_', figTag, '.png']));
    end
end

% Save peak latency and amplitude data
save(fullfile(outputDir, 'Step7GraphGFP_Subplots_Peaks.mat'), 'allPeaks', 'timeRanges');
disp(['Saved ', num2str(length(condNames) * 2), ' figures + peak data to ', outputDir]);
end

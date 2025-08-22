function PlotMaxHistograms(csvPath, outputFolder)
% csvPath = Path to .csv file where each column has max values
% Creates one figure with histogram subplot for each subject

    % Read the CSV as a table (handles variable-length columns)
    data = readtable(csvPath);

    % Get subject names
    subjectNames = data.Properties.VariableNames;
    numSubjects = length(subjectNames);

    % Determine subplot grid size
    subplotCols = 4;  % Adjust as needed
    subplotRows = ceil(numSubjects / subplotCols);

    % Create output folder if it doesn't exist
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end

    % Create figure
    fig = figure('Name', 'Max Value Histograms', 'Position', [100, 100, 1400, 800]);

    for i = 1:numSubjects
        subplot(subplotRows, subplotCols, i);

        % Extract non-NaN max values for this subject
        maxVals = data{:, i};
        maxVals = maxVals(~isnan(maxVals));

        % Define bin edges
        binEdges = [-Inf, 0:10:1000, Inf];
        
        % Use original max values (no log) and custom bins
        histogram(maxVals, 'BinEdges', binEdges);
        set(gca, 'YScale', 'log');
        
        % (Optional) Set x-limits if you want to focus the visible range
        %xlim([-600, 600]);

        title(strrep(subjectNames{i}, '_', '\_'), 'Interpreter', 'tex');
        xlabel('Max (µV)');
        ylabel('Count');
        grid on;
    end

    sgtitle('Max EEG Values per Subject');

    % Save figure
    saveas(fig, fullfile(outputFolder, 'SubjectMaxHistograms.png'));
    disp(['Saved histogram figure to: ', fullfile(outputFolder, 'SubjectMaxHistograms.png')]);
    close(fig);
end

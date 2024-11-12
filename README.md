# Ozmeral_Lab_Project

This is the code for the analysis I am working on in my current lab.

Overview:

Right now, I am analyzing EEG data to compare how older normal hearing and hearing-impaired individuals react to changes in sound location. I am particularly interested in the brain response differences between those wearing omnidirectional hearing aids, which amplify sounds in all directions, and directional hearing aids, which amplify sounds only in front of the listener. I am also investigating concepts such as sound arrival at specific locations relative to the listener, presentation on the left or right, the total change in angle of the sound, and the difference between active and passive listening. To complete these steps, I am using MATLAB programming and an application called Brainstorm. 

This code is currently being used to analyze subject data, but please note that these portions have not been uploaded for privacy reasons.

Program specifics:

My investigation is made up of a number of steps. Here are the overall themes, all of which I have learned to program in MATLAB:
- Frequency filtering: removing frequencies that are above 100 Hz or below 0.1 Hz, as these are not relevant to the study
- Artifact detection: most notably, blinking majorly contaminates the data, and these artifacts must be removed
- Epoching: the data must be divided into smaller segments and sorted based on various conditions
- Averaging: relevant epochs must be averaged to see the larger picture

Besides learning those specifics, this project has furthered my general problem-solving abilities within a programming context. For example, our experiment consisted of four different conditions. Each subject did these different orders, and they were grouped into various blocks of time depending on the subject. I had to figure out a way to use information from a table to divide the data and label them with the various conditions and blocks.

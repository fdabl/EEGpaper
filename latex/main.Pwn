\documentclass[a4paper, man, floatsintext]{apa6}

\usepackage[T1]{fontenc}
\usepackage[utf8]{inputenc}
\usepackage{amsmath}
\usepackage{amssymb}
\usepackage{csquotes}
\usepackage[american]{babel}
\usepackage{enumitem}
\usepackage{hyperref}
\usepackage{verbatim}
\usepackage{bbding}
\hypersetup{
    colorlinks = true,
    citecolor = blue,
    urlcolor = blue
}

\usepackage{parskip}
\setlength{\parskip}{0mm}
%\setlength{\footnotesep}{0.0cm}

\usepackage{xcolor}
\newcommand\notes[1]{\textcolor{red}{#1}}

\usepackage{lineno}
\usepackage[backend=biber, style=apa]{biblatex}
\DeclareLanguageMapping{american}{american-apa}
\addbibresource{../bibliography.bib}

\title{A primer on EEG data analysis}
\shorttitle{EEG DATA ANALYSIS}
\author{Fabian Dablander}
\affiliation{University of Tübingen}
\leftheader{Dablander}

\abstract{Analyzing large amounts of noisy, non-linear, high-dimensional time-series data is
no easy task. The analysis of EEG data presents such a challenge. Between initial data
pre-processing, statistical analysis, and the final figure
presented in publications lie many subtle and not so subtle steps. Even after familiarizing
oneself with these steps, methods papers proposing fancier analyses and more clever
pre-processing techniques are published on a regular basis, making it difficult to keep up. Beginning
researchers might find themselves confused in the jungle of EEG data analysis, paralyzed by the
many routes they could take. In this paper, I try to give an overview of the EEG
data analysis pipeline, from pre-processing to statistical analysis.
In addition to discussing standard analysis practices and their extensions,
I discuss novel approaches such as multilevel modeling, general additive mixed models,
cognitive model-based approaches, as well as their main challenge: increasing the signal to
noise ratio in single trials. I have included many references the interested reader may find
helpful, a technical appendix that derives the basic mathematical ideas presented in the main
text, and a corresponding online appendix providing intuition in Python.}

\keywords{EEG, overview, machine learning, single-trial analysis, wavelets}

\begin{document}
\maketitle
The electroencephalogram (EEG) has long been a popular tool to measure cognitive
processes on a millisecond time scale. Initially developed by Hans Berger in the 1920s, it
quickly established itself as an indispensible tool for cognitive neuroscience and clinical
practice \parencite[for a detailed overview of its history, see][]{collura1993history}.

As with any tool, EEG has both advantages and disadvantages. Understanding how the signal
EEG measures is generated sheds light on the features of the tool
\parencite[for a detailed overview, see][]{buzsaki2012origin}.
Briefly, postsynaptic potentials can last up to several hundreds of milliseconds, and create tiny
dipoles at the neurons. When large populations of spatially aligned
neurons receive similar inputs (excitatory or inhibitory),
their dipoles are summed and produce an event-related component. Unfortunately,
an EEG electrode does not only measure the dipole that is created at its scalp
location. Instead, because the brain is a conductive medium, the electricty due to one
dipole spreads across the entire scalp, a phenomenon termed \textit{volume conduction}.

Resultingly, because EEG measures neural activity directly, it yields very high temporal
resolution, allowing us to measure brain dynamics as they evolve \parencite{da2013eeg}. This is in contrast
to fMRI, which relies on blood flow, or PET and NIRS, which rely on metabolic activity.
Additionally, EEG is non-invasive, and fairly inexpensive.
Due to volume conduction, however, its spatial resolution is very poor\footnote{It is so
poor that, ``if you had data only from one electrode, you would not be able to determine
with any reasonable accuracy where in the brain that signal was generated.''
\parencite[][p. 26-27]{cohen2014analyzing}}. While we can determine wich recorded
activity belongs to which electrode -- \textit{topographical
localization} -- a much harder challenge is to determine to which physical neural source it
can be attributed to -- \textit{brain localization}.

While EEG has been in use by researchers and clinicians for many decades, recent years have seen a
rise of applications aimed at the mainstream market (from
\href{http://neurosky.com/2015/09/eeg-games-top-5-list-playing-with-your-brainwaves/}{games}
to \href{http://www.choosemuse.com/}{meditation}), and companies aimed at the
open-source, ``do-it-yourself'' community have cropped up (see \href{http://www.openbci.com/}{OpenBCI}).
A main challenge for increased usability and popular uptake is to achieve relatively noise-free recordings from
mobile EEG systems \parencite[which does seem in reach, see][]{ries2014comparison, mullen2015real}.

As with any measure that allows going beyond behavior, measuring cognitive processes on
a more fine-grained scale, EEG records massive amount of data; per electrode (commonly
32-256), per subject, and per time-point (sampling rates of up to 500Hz are common). Figure 1
below shows raw EEG data.

How do we pre-process, clean, and analyze such large amounts of data?
How do we navigate the jungle of EEG data analysis without
being paralysed by its many routes? In this paper, I provide an overview of those
challenges, linking to additional ressources for more in-depth treatment. While useful for
the beginning researcher, I also hope that some ideas, perspectives, or references are
new even to the experienced researcher.

\begin{figure}[!ht]
    \centering
    \includegraphics[width=15cm, height=8cm]{pics/raw.png}
    \caption{\small{Shows non-epoched, raw channel data for a select group of electrodes.
Shaded in blue is a blink artefact.}}
\end{figure}

\section{Overview of this paper}
There are many different ways to analyze EEG data, and to do justice to the complexity
would require several books \parencite{cohen2014analyzing, luck2014introduction,
freeman2012imaging}. Consequently, I will mainly focus on
\textit{event related potentials} (ERPs) and their analysis.

Event-related potentials are changes in the ongoing EEG activity due to stimulation;
exogenous ERPs are elicitated by the visual, auditory, or somasensory properties of a
physical stimulus. More interestingly, endogenous ERPs are elicitated by internal
brain processes and can be used to study cognitive processes \parencite[thee exact origin
of ERPs is debated, see][]{bastiaansen2012beyond}.

In the first part of the paper, I will give an overview on different way
of representing the multidimensional EEG signal and the pre-processing pipeline including
various ways of normalization, artefact detection, and filtering.
Explaining the standard statistical approach -- averaging over trials and
individuals -- and a recently suggested ``massive univariate'' alternative
\parencite{groppe2011mass1}, I will argue that a regression based formulation allows for
more powerful modeling \parencite[see][]{smith2015regressiona}. Within this framework, I
will try to make the case for non-linear, multilevel modeling of the entire ERP wave
\parencite[see][]{tremblay2015modeling}. A brief section hinting at the machine learning
techniques used in research on brain-computer
interfaces (BCIs) is followed by a short section on cognitive-model based approaches
\parencite[see][]{forstmann2015introduction}. Lastly, I will briefly present approaches
aimed at increasing the signal to noise ratio in single trials.

While not discussing means to increase the spatial localization of EEG in detail
\parencite[for an overview, see][]{jatoi2014survey}, I will hint at how using
different spatial filters and pre-processing methods in general may influence the
conclusions drawn from the data \parencite[see also][]{cohen2014five}.

There is a crucial issue with (EEG) data analysis of which the reader should be
aware, but which will not be discussed in detail in this paper. As with any method
that requires many pre-processing steps, the choice of algorithms and statistical analyses are enormous
\parencite{carp2012secret, cohen2014analyzing}, and hold many degrees of
freedoms or ``forks in the garden'' \parencite{gelman2014statistical}
which allow researchers to present anything as statistically significant
\parencite{simmons2011false, luck2016significant}. Open data, reproducible code, and registration
of one's methodology, pre-processing pipeline, and statistical analysis prior to data collection
alleviate these issues and are important steps towards a more transparent and solid science. A new
publishing format called \textit{Registered Reports} implementing these changes has 
already been adopted by journals from various fields \parencites[e.g.,][]{chambers2013registered,
king2016registered}; see also
\href{https://osf.io/8mpji/wiki/home/}{https://osf.io/8mpji/wiki/home/}.

While not discussing the mathematical ideas in the main text in detail, a corresponding technical appendix
includes their derivations, while an online appendix provides intuition in Python.
All materials can be found on \href{https://github.com/fdabl/EEGpaper}{https://github.com/fdabl/EEGpaper}.


\section{Preliminaries and pipeline}
\subsection{Signal representation}
The EEG signal is multidimensional, encoding information in frequency,
amplitude, phase, and time. Taking a look at the sine waves plotted in
figure 2, frequency refers to the number of oscillations per second, measured in Hertz.
Peak-to-peak amplitude denotes the height of the wave, and is commonly squared to yield
power, which is a measure of the amount of energy in a certain frequency band at a certain
point in time. Phase is a circular measure, and gives the offset of the signal; thinking
in terms of complex numbers, power is the radius squared, and phase is the angle.
Depending on what features we want to highlight, the EEG signal can be represented in
different domains. Figure 2 visualizes those domains in the first row, while the second
row shows their respective bases.

\begin{figure}[!h]
    \centering
    \includegraphics[width=15cm, height=10cm]{pics/comparison.png}
    \caption{\small{First vertical part shows the averaged ERP waveform of electrode FPz
based on all trials, and three single trials below. The second part shows the power spectrum of the average
ERP via a Fourier transform; plotted below are sine waves of varying amplitude,
frequency, and phase. The last part shows the result of time-frequency decomposing
the single trials and subsequently averaging them. Power values are decibel normalised against
the baseline; plotted below are Morlet wavelets varying in width and frequency.
EEG data are taken from the EEGLAB tutorial, and are not pre-processed except
bandpass filtered ($1-25$Hz), but the general theme becomes clear.}}
\end{figure}

\subsubsection{Time domain}
The first, vertical part of figure 2 shows the trial-averaged ERP waveform for a single
channel and five individual trials below. The power of the individual trials is much higher,
and they look much noisier. Averaging is the most common approach of increasing the signal
to noise ratio, which grows with the square root of the number of trials, $\sqrt{N}$.
However, averaging in the time domain can lead to severe distortions
when single trials differ in their onset, i.e. are not phase-locked, also referred to as
\textit{latency jitter}. While there are some remedies
\parencite[see][pp. 271]{luck2014introduction}, time-frequency based averaging has become
the dominant approach over the last decade. In the time-domain, researchers look at peaks of
the waveform such as P300 or N100, which are named after their polarity and latency;
although there are different naming conventions \parencite[see][pp.
72]{luck2014introduction}, inconsistently applied\footnote{The inconsistency in terminology across
a broad range of concepts is one main challenge of EEG research \parencite[see][]{cohen2014five}.}.
Research on various ERP components is vast; for a whole book on
``ERPology'', see \textcite{luck2011oxford}.

\subsubsection{Frequency domain}
Oscillatory brain activity is important for the functional communication between populations
of neurons, and is thus integral to sensory and cognitive functions
\parencite{cohen2015cycles, bacsar2001gamma}. By viewing the ERP waveform in the time-domain,
it is difficult to extract the frequencies at which neurons oscillate. Using the Fourier
transform (see technical appendix), the EEG signal can be decomposed into sine waves
of different frequencies, amplitudes, and phases. The second
part of figure 2 shows the Fourier decomposition of the averaged ERP, and sine waves
varying in parameters. The most common frequency bands are denoted delta
($0-3.5$Hz), theta ($3.5-7.5$Hz), alpha ($7.5-12.5$Hz), beta ($12.5-30$Hz), gamma
\parencite[$30-60$Hz; classification taken from][p. 31]{freeman2012imaging}\footnote{These are not arbitrary
groupings, but result from neurobiological mechanisms of the brain which seem to be universal
across the mammalian species \parencite{buzsaki2013scaling}.}. Corresponding to event
related potentials in the time-domain, researchers can look at event-related oscillations
in the frequency domain \parencite[EROs;][]{herrmann2014time}.
Note that the Fourier transform is a mathematical tool, and it describes which
kind of sine waves we would need to reconstruct the signal; observing a sine wave with a
certain frequency resulting from a Fourier transformation does not necessarily entail that the
brain oscillated at that frequency \parencite[see][p. 223-226]{luck2014introduction}.

\subsubsection{Time-Frequency domain}
The Fourier transform assumes a stationary signal i.e., that properties of the
signal do not change over time, an assumption clearly violated in EEG. Additionally,
it provides no straightforward means to extract time information;
for example, it is not at all clear whether the frequency component of,
say, 5Hz is constant over time or whether it occurs in short bursts of a few
milliseconds. This is because the Fourier transform uses sine waves as basis which do not
have a temporal localization.
To quantify the time dynamics of different frequency components,
one can use the short-time Fourier transform, multitaper methods, or other techniques
\parencites[see][ch. 15-17]{cohen2014analyzing}[for a technically detailed comparison,
see][]{wacker2013time}. In recent years, however, wavelets have
become the dominating approach for time-frequency decomposition
\parencites[see also][ch. 2-4]{freeman2012imaging}[]{herrmann2014time}.

There are many different wavelet families, but not all are useful for EEG data.
Of central importance is that the wavelet looks similar to
the signal we want to analyze. For EEG data, (complex) Morlet wavelets are commonly used,
which are the result of convoluting a (complex) sine wave with a Gaussian window.
The frequency of the sine wave determines at which frequency we decompose, while the width of the
Gaussian window controls the temporal resolution; the number of frequencies and the widths
of the Gaussian windows are non-trivial parameters to set, and can markedly impact the
results obtained \parencite[see][pp. 168]{cohen2014analyzing}. For more on wavelets,
see \textcite{strang1994wavelets}, \textcite{graps1995introduction} and
\textcite[][ch. 3-4]{freeman2012imaging}. For a review of applications and measures used
with time-frequency analyses, see \textcite{roach2008event}.

To avoid pitfalls with averaging in the time-domain due to non-phase locked
activity, single-trials are commonly transformed into the time-frequency domain and
the resulting power values, which are non-negative, are subsequently averaged \parencite{herrmann2014time}.
The third part of figure 2 gives the result of this procedure;
shown below are members of the \textit{Morlet wavelet family} varying
in frequency and width. There is an inherent trade-off, known as the \textit{Gabor limit}:
the smaller the width of the Gaussian window, the better the resolution in time --
at the cost of the resolution in frequency.

\subsection{Pre-processing}
\subsubsection{Re-referencing\protect\footnote{This section is heavily influenced by
\textcite[][p. 150-164]{luck2014introduction}.}}
It is important to stress that EEG measures electric \textit{potential} between
electrodes and a reference electrode in (micro) Volt. Thus it is a relative measure, and
can be subject to big and subtle changes. More broadly, an \textit{EEG channel} is comprised of an active,
ground, and reference electrode. We can use the term \textit{absolute voltage} to refer
to the potential between an active electrode and the average of the rest of the head.
Let $A$ and $G$ denote absolute potentials of an active electrode
and the ground. We could have the amplifier record $A - G$, the voltage
between $A$ and $G$; however, because of the way amplifiers work, $G$ is contaminated with
electrical noise, rendering this approach futile. By introducing another electrode $R$, our reference
electrode, we can compute the difference between the voltages, $(A - G) - (R - G) = A -
R$, and thus eliminate electrical noise. Amplifiers operating this way are called
\textit{differential amplifiers}.

Some recording systems set the reference electrode themselves (e.g., Cz), but for subsequent
data analysis one usually wants to change this. This process is called
\textit{re-referencing}, and can be done offline via simple operations. For example,
re-referencing to the electrode of the right mastoid is done by subtracting its
potential from all other electrodes (e.g., $A_m = (A - R) - (M - R) = A - M$). An
appealing choice is to re-reference to the average of all channels because this does not
bias the result to any hemisphere, and also minimizes noise. However, as apparently
not many researchers are aware of \parencite[see][pp. 162]{luck2014introduction}, this can
have subtle and not so subtle side-effects. For the latter, note that taking the average
as reference impedes quantitative comparisons across experiments, because the ERP waveform
will be influenced by the place and number of channels recorded. For an overview of these
and other issues, see \textcite{dien1998issues}.

In sum, choosing a reference is an important pre-processing step that can drastically
influence the results, and should be done carefully.

\subsubsection{(Temporal) Filtering}
Filtering is usually done on the continuous, non-epoched EEG signal and thus is the
first step in the preprocessing pipeline; although being a linear operation,
the exact order does not matter \parencite[see][pp. 246]{luck2014introduction}. There are two major use-cases for
filtering \parencite[see also][ch. 7]{luck2014introduction}. Note that the Nyquist-Shannon
sampling theorem states that analog signals are adequately sampled only at a frequency at
least twice as high as the original signal. In the recorded signal, higher frequencies
will appear as artefactual low frequencies, a phenomenon called
\textit{aliasing}\footnote{For a beautiful demonstration, see
\href{https://jackschaedler.github.io/circles-sines-signals/sampling2.html}{here}.},
This is seen as slow drift in the EEG signal, and is removed by \textit{high-pass}
filters of about 0.1Hz. The second main use case is to reduce noise, and here high-pass
filters can help attenuate low frequencies caused by the skin. Additionally, components with
frequencies higher than 100Hz are often muscle artefacts, and can be removed by \textit{low-pass} filters.
Filters in the frequency domain have an equivalent representation in the time-domain. In
the time-domain, filtering is done by computing a running average or convolution, which results in
\textit{temporal smearing} -- high-frequency noise is attenuated, and the waveform looks nice and smooth.
While decreasing temporal resolution, it increases frequency resolution.
Filtering is a distortion of the signal. Especially high-pass filters of 0.1Hz can be
problematic; they can increase statistical power \parencite{kappenman2010effects},
but might also significantly distort the ERP waveform \parencite{tanner2015inappropriate}.

\subsubsection{Epoching}
The recording system continuously samples the EEG signal; for subsequent analysis,
however, we need to know when a trial started and ended. For this reason one sends event triggers
during the experiment, for example indicating stimulus onset. \textit{Epoching} refers to
time-locking the signal to stimulus onset (for each trial), such that $t = 0$ at this
point. In other words, epoching is the process of going from a two-dimensional
\textit{channel $\times$ time} to a three-dimensional \textit{channel $\times$ time
$\times$ trial} representation. The \textit{baseline} refers to time before stimulus, see also figure 2.

\subsubsection{Baseline correction}
Factors not related to the experimental procedure like skin hydration and static charges
in the electrodes induce an amplitude offset in the EEG signal. Baseline correction
is applied to each epoch in order to mitigate these issues by subtracting the mean pre-stimulus
amplitude from the post-stimulus amplitude. However, this seemingly innocuous procedure
can have some subtle implications \parencite[see][pp. 251]{luck2014introduction}.
For example, if the inter-trial interval is set too short, signal from the previous
trial can overlap with the baseline of the current trial, and bias the baselining procedure
\parencites{woldorff1993distortion}[see also][]{smith2015regressionb}.

Note that time-frequency based analyses often do not require baseline correction
because different frequency components are isolated, and those corresponding to low
drifts or vertical offsets can subsequently be ignored.

\subsubsection{Artefact rejection and detection}
Artefacts are systematic or unsystematic distortions of the EEG signal
which decrease the signal to noise ratio, can lead to systematic biases
when comparing experimental conditions, and can suppress sensory input
\parencite[e.g. through blinks; see also][ch. 6]{luck2014introduction}. Artefact
\textit{rejection} entails discarding artefact
contaminated trials (across all channels) based on certain amplitude thresholds; for a
review on dealing with eye movement induced artefacts, see \textcite{plochl2012combining}.
Artefact \textit{detection} refers to identifying the influence of artefacts and subsequently
subtracting them from the signal. On this front, methods based on independent component
analysis (ICA; see technical appendix) are most popular. ICA is a blind source seperation
method that finds maximally statistically independent sources of variance in the EEG
signal\footnote{Statistical independence can be quantified by mutual information, a
concept from information theory \parencite[see][]{hyvarinen2000independent}. However,
there are many different algorithms for ICA. \textcite{delorme2012independent}
compared and scored 18 of them.}. It results in a set of weights that indicate
the component of each electrode in the signal. Artefactual components are thus
identified and can be subtracted \parencite{delorme2007enhanced}.

While on the topic, let me note that another use of ICA is to submit the components to subsequent data analysis
instead of the \textit{sensor} data. This is called \textit{spatial filtering}, and there
are other methods like principal component analysis (PCA), which, like ICA, only uses
statistical information in the data, or the Surface Laplacian, which uses physical
properties such as the interelectrode distances to project the data onto a new space
\parencites[see][ch. 23-24]{cohen2014analyzing}{cohen2014comparison}.

\subsubsection{Baseline normalization}
While baseline correction is a linear operation, baseline normalization is a non-linear
operation that is commonly carried out when doing time-frequency based analyses.
EEG signal has a $1 / f$ scaling problem -- its power decreases non-linearly with
increasing frequency. This impedes quantitative comparisons of power across frequency
bands and violates common parametric assumptions because raw power values are skewed and
non-negative. To alleviate this problem, several transformations have been proposed
\parencite[see][ch. 18]{cohen2014analyzing}. Here I just mention the popular decibel
conversion, $dB_{tf} = 10 \cdot \log (\frac{\text{post}_{tf}}{\overline{\text{pre}}_{tf}})$,
where $\overline{\text{pre}}$ denotes the average baseline amplitude, $\text{post}$
denotes post-stimulus activity, and $t$ and $f$ index time and frequency points,
respectively. The time-frequency decomposition in figure 2 shows decibel-converted power.
The resulting scale is logarithmic and relative to the baseline. Needless to say, this
means that choosing the baseline becomes a critical issue.
Other transformations such as percent change or the Z-transform give different results,
and thus one needs to be aware of those differences. Similarly, these transformations might
not be innocuous. For example, \textcite{hu2014single} found that
using the percent change transformation leads to a bias in estimating
event-related desynchronization and synchronization.

Above I have merely scratched the surface of the preprocessing pipeline. Steps
that are experiment, task, or equipment specific further increase the list of preprocessing
steps. Concluding, preprocessing holds various pitfalls and many degrees of freedom
\parencite[for a quantification in fMRI research, see][]{carp2012secret}.
An important step towards a more standardized approach towards early stage preprocessing
is taken by \textcite{bigdely2015prep}.

\section{Statistical analysis}
After pre-processing, we can engage in statistical analysis, either to do confirmatory
hypothesis testing, or to explore the data set and generate new hypotheses. Of course, we
can and should do both, but we need to be aware that statistical procedures carry
little evidential value when done in exploratory settings \parencite{de2014meaning}.
As always, replication is the best statistic.

Having said that, how can we analyze our data? Similar to the many steps involved in pre-processing, there
is a huge amount of possible models we can employ -- even when just looking at
event-related potentials. For the remainder, it is useful to think of the EEG data as a
three dimensional array indexing electrode, time, and trial
\parencite[EEGLAB's convention;][]{delorme2004eeglab}.

\subsection{Standard ERP analysis}
Usually, in the time domain, \textit{grand average} event-related potentials are
constructed for each condition by averaging over trials and participants. Sometimes
electrodes are clustered (frontal versus anterior) by additionally averaging over them.
Usually, the dependent variable is peak-amplitude of the ERP component, peak-to-peak or
base-to-peak amplitude differences, or the average voltage over some time window
\parencite[see][ch. 9]{luck2014introduction}. Similar to behavioral measures, the
dependent variable is submitted to a standard parametric test, i.e. a t-test or ANOVA.

For example, \textcite{giraudet2015neuroergonomic} had participants do a simulated air
traffic control task using two different visual notification designs -- one subtle
(``Color-Blink''), the other more salient (``Box-Animation''). Concurrently, participants
had to perform an auditory task requiring them to react to rare pitch tones. The P300
component to these tones were taken to indicate remaining attentional ressources, and its
amplitude, measured by taking the average within the 364 to 464 post-stimulus window, 
was greater for the salient design. This seems to establish the P300 component as a viable
marker of design efficiency -- good design takes up less attentional ressources.

However, as mentioned briefly above, we can also analyse the signal in the frequency
domain. For an example, \textcite{goodin2012high} stimulated participants with binaural
beats at 7Hz (theta) and 16Hz (beta). Fourier
transform was applied to the recorded signal and absolute spectral power was computed for
each electrode for two frequency ranges corresponding to the binaural beats stimulation
(5.5-7.5Hz for theta and 15.5-17.5 for beta). Electrodes were grouped into frontal,
central, parietal, temporal, and occipital areas and subsequently averaged. Applying a
within-subject ANOVA, the authors did not find differences in spectral power between
stimulation (beta and theta) and control conditions, suggesting that binaural beats to not
alter cognitive processes.

As an aside, note that when the parametric assumptions of statistical tests
are violated, for example due to outliers, it might be invalidated and bias the
conclusions drawn from the data. Recently, \textit{robust procedures} have been suggested which are not as
sensitive to parametric violations as their traditional counterparts
\parencites[see][]{wilcox2012introduction}[][for an implementation]{pernet2011limo}.
For good applications, see for example \textcite{rorden2007improving}
and \textcite{rousselet2012improving}.

\subsection{Massive univariate approach}
In the standard approach, researchers specify a time window in which they look at the
averaged ERPs across conditions and submit this to a parametric technique such as ANOVA.
Specifying a window by hand carries several problems with it; first, there is the danger
of ``double dipping'' by selecting windows contingent on data
\parencite{kriegeskorte2009circular, vul2009puzzlingly} -- this points to the issue
of confusing exploratory and confirmatory research settings; second, one might miss
interesting effects outside the specified time window, which can quickly happen even
between electrodes; and third, standard analysis does not provide information about the onset
and offset of the stimulus induced change in the EEG signal. Instead, the \textit{massive univariate approach}
entails conducting standard parametric tests on each time point for each electrode over
the averaged ERP wave \parencite{groppe2011mass1, groppe2011mass2}. The massive univariate approach originated
in fMRI research, where thousands of voxels are subjected to statistical tests, which requires
controlling of the false positive rate \parencite[see for example][]{genovese2002thresholding}.
Different multiple comparison methods, among them Bonferroni, permutation statistics,
false discovery rate, and cluster based corrections, have been suggested to
alleviate the problem \parencite{maris2007nonparametric}.

An example highlighting the advantages of the massive univariate approach is given by
\textcite{scheer2016steering}. Briefly, the authors had participants do a steering task
while intermittently presenting distracting environmental sounds or beep tones. Using said
analysis allowed them to, of course, identify the ERP components elicited by the
distractors and determine their difference between the environmental and beep distractors,
but also map the spatio-temporal dynamics of the ERP component. Concretely, they found
that steering diminishes the amplitudes of early and late P300, as well as the
re-orientation negativity to the environmental sound distractor but not to beep tones.

As an aside, if we are interested in quantifying the evidence provided by the data,
\textit{p}-values are a moot choice because they overestimate this evidence
\parencite{berger1987testing}. Using results from \textcite{liang2008mixtures}, \textcite{rouder2009bayesian}
developed a Bayesian alternative to the classical t-test; however elegant the Bayesian
approach may be, I am not sure it is appropriate here, especially since the focus of
Bayesian techniques is not on error control.

In general, although the massive univariate approach seems somewhat inelegant, it is a
good start (Guillaume Rousselet,
\href{https://twitter.com/robustgar/status/716662407305814016}{public communication}), and
certainly a huge improvement over more traditional analyses.

\subsection{Regression-based estimation and testing}
Both approaches presented so far can be cast in a regression framework
\parencite{smith2015regressiona, burns2013comparison}, which
provides a more powerful toolkit suitable to extensions
\parencite{smith2015regressionb}. Before diving in, let's take a step back and ask:
why is averaging a good idea? To answer this question, we have to think about our model.
Implicitly in the standard approach, we assume that, on each trial for each electrode,
the measured electrical activity is composed of the true activity and normally distributed
noise. For this model, the mean is an unbiased and efficient estimator \parencite[but not
inadmissible; for example, a hierarchical model yields better
estimates, see][]{efron1977stein}.

Taking the mean over time-locked single-trial ERP waves -- that is, just constructing the
average ERP -- is equivalent to running a regression with only an intercept as predictor
(see the technical appendix for a refresher on how regression works, and
\textcite[][pp. 159]{smith2015regressiona} for a longer explanation of why this is true).

But regression is a much more general approach. For example, the standard analysis approach
does not have a natural way of representing continuous predictors. Thus it is common
practice to split continous predictors into factors and continue with ANOVA
\parencite[][p. 1]{tremblay2015modeling}, which naturally decreases statistical power.

In general, when averaging over participants, we need to be conscious that we are modeling 
the \textit{average participant} -- on an individual level, the measure under
scrutiny might look very different \parencites[for example, see][]{gaspar2011reliability, haegens2014inter}

Instead of ignoring the inter-subject variability, we can specify a model first on the trial-level,
and subsequently subject these estimated beta weights to a model on the participant-level
\parencite{pernet2011limo, burns2013comparison}. The same methodology
is dominating univariate fMRI analysis \parencite{poline2012general}, and is referred to
as \textit{statistical parametric mapping} or GLM-approach (for General Linear Model)\footnote{These
developments in EEG analysis seem parallel to the developments in the fMRI
community, but with a time lag of about ten years. The GLM approach in fMRI has been criticized both on
statistical \parencite{monti2011statistical} and conceptual \parencite{stelzer2014deficient}
grounds.}.

\subsection{Non-linear multilevel models}
Before moving on, we have to clarify crucial terminology. Proponents of the GLM approach
often call it \textit{hierarchical single-trial} analysis. Single-trial because for each
participant seperately, we estimate the ERP waveform (1\textsuperscript{st} level).
Hierarchical because the result of these individual estimates are then submitted to
a classical or robust parametric procedure, looking for differences on the group level \parencite[2\textsuperscript{nd}
level;][]{pernet2011single, pernet2011limo}.
While this approach allows us to quantify the between-subject variance, I hesitate to call it
hierarchical \textit{proper}, because it does not regularize the estimates by shrinking
them toward the grand mean, as is common when submitting both levels to what is frequently
called a \textit{linear mixed}, \textit{hierarchical}, or \textit{multilevel} model
\parencite[see technical appendix;][]{baayen2008mixed, sorensen2015bayesian, bates2014fitting}.
It further does not allow to model variation
in the stimulus materials. Failing to model variability in stimuli is a long standing issue in
psycholinguistics and other fields, which can lead to spurious conclusions
\parencite[for example, see][]{judd2012treating}.

In addition to built-in regularization and the possibility to model all sources of variability,
and in contrast to the standard approach, mixed models allow for unbalanced designs
(which are common when events are time-locked based on participant's response), handle missing data,
and are invariant to violations of sphericity and heteroscedasticity
\parencite{bagiella2000mixed, tibon2015striking}.

Let's take another step back. When you look at an ERP waveform in the time-domain,
it does not look linear at all (see figure 2).  Instead of pursuing the massive univariate path --
testing a time-wise normal model thousands of times -- another approach
is to model the entire time-course of the ERP waveform using generalized additive (mixed) models
\parencite[GAMMs;][]{wood2006generalized}. Instead of forcing linearity on the data, we
let the data inform the functional shape we are estimating \parencite{tremblay2015modeling}.
This approach inherits all benefits discussed
above for the linear mixed model, but increases the modeling flexibility dramatically by
getting rid of linearity. In a sense, it is the continuous version of the massive univariate approach;
instead of modeling the time-course of the ERP wave by means of significant t-tests, GAMMs allow
smooth estimation across participants, with regularization built-in. In this
approach, we appropriately treat the data as being non-linear, high-dimensional
time-series data. Similary to the massive univariate approach, which can correct for the
dependency in, and clustering of the data, GAMMs can account for this auto-correlation by
including an autoregressive model.

While \textcite{tremblay2015modeling} give an overview of applying GAMMs to ERP data,
\textcite{meulman2015age} compare the use of traditional analysis with GAMMs by applying
them to answer questions about age effects in grammar processing.

A note of caution. GAMMs are complex models, and an overhead in complexity must always be
warranted by the problem one tries to solve. In any case, I believe mixed models and GAMMs
to be a novel addition to the EEG researcher's methodological toolbox, allowing us to
discover hidden patterns in the data that fuel theory building and computational modeling.

\subsection{Machine learning in BCI}
Not shying away from pathos, the main objective here is to \textit{decode} brain signals in order to
control machines. Frequently, the issue is one of classification: does this
brain signal correspond to \textit{this} or \textit{that} brain state? Since this
should be as efficient as possible, research in this area focuses on single-trials,
instead of having the participants do many trials and average over them \parencite{lemm2011introduction}.
Because we do not increase the signal to noise ratio by averaging, the main issue is the
low signal to noise ratio when focusing on single trials. Several spatial and temporal filters
can be employed to the raw signal (more on that below), which leads to a subsequent high-dimensional
feature space. Because of this high-dimensionality, most classifiers employed a linear,
with some sort of regularization built-in \parencite{blankertz2011single,
muller2003linear}\footnote{But see the recent winning entry for the
Kaggle BCI challenge \href{https://www.kaggle.com/c/inria-bci-challenge}{here}.}.
Among the most popular is linear discriminant analysis (LDA), which is
reasonably robust against violations of its assumption, and is optimal when they are met
\parencite{blankertz2011single}. For an extensive overview of different classification
algorithms as applied to BCIs, see \textcite{lotte2007review};
for an overview of BCI platforms and pipelines, see \textcite{schalk2004bci2000} and
\textcite{muller2008machine}.

\subsection{Model-based cognitive neuroscience}
Another, quite different path compared to traditional analysis focuses on developing
mathematical models to bridge the gap between levels
of analysis by analyzing behavioral and neuronal data in a joint model, using neural data
to constrain behavioral models, or using the behavioral model to predict neural data
\parencite{forstmann2015introduction, turner2016approaches}. This is an exciting
development more generally, in that instead of relying on atheoretical, purely
statistical models like regression, cognitive models more strongly correspond to, and
instantiate a theory. Parameters of cognitive models are often directly interpretable
with respect to the theory.
For a great motivating article of applying mathematical models to problems in cognitive neuroscience,
see \textcite{forstmann2015introduction}. For an introduction and review on applying
cognitive models to the study of mind-wandering, see \textcite{hawkins2015toward}.

\subsection{Denoising of single-trials}
Traditionally, the most powerful tool to increase the signal to noise ratio is averaging
over trials; this is one of the main advantages of the standard analysis.

Averaging acts as a filter: it allows phase locked activity to pass, but
blocks non-phase locked activity from contributing to the average. Because single-trial
analysis cannot use such a filter, it has to rely on different techniques.
One might distinguish between \textit{sensor} versus \textit{source-based} methods. The former
measures some variable of interest, say peak measurement, in the space the EEG signal was
recorded, while the latter techniques decompose the signal to estimate mathematical
sources on which the peak is subsequently measured \parencite[see][p. 1197]{de2012let}.
For example, \textcite{de2012let} compared four different methods of single-trial
filtering on a classification benchmark, finding that ICA based methods improve upon using
the raw signal, while multiple regression and bandpass filtering did not. The authors used
bandpass filtering instead of a wavelet based technique \parencite{quiroga2003single}
because the latter was not yet fully automatic. However, recent work extends the wavelet
based approach, allowing for fully automatic denoising \parencite{ahmadi2013automatic}.
Concretely, the method works by first doing a wavelet decomposition on the average ERP,
hard thresholding the wavelet coefficients incorporating their dependencies, and
subsequently reconstructing the signal. While this approach is already very promising, new
methods are developed at a rapid pace \parencite[for examples, see][]{van2016single,
treder2016lda}, making an update and extension of the work by \textcite{de2012let}
desirable.

The point of this section was not to provide a detailed overview, but rather to hint at
possible solutions for the problem of noise in single-trials. In any case, one may well
state that single-trial denoising represents the cherry on top of the already complex
EEG data analysis pipeline.

\section{Conclusion}
While EEG is a powerful tool of modern cognitive neuroscience, illuminating neural
dynamics as they evolve, EEG data analysis presents are superb challenge, with many
complexities and degrees of freedoms involved.

Having never taken a class on EEG data analysis nor signal processing, I have tried to give
a broad overview of the basic issues, statistical approaches, new ideas, and tooling
surrounding EEG data analysis. While possibly useful to the similarly uninitiated,
I hope that some ideas, perspectives, or references were new even to the experienced
researcher.

After presenting the basic, already quite involved pre-processing steps,
I have argued that statistical approaches that collapse across participants or
trials are suboptimal. An improvement upon this standard practice is provided
by the massive univariate approach, especially when
conducted to respect inter-individual differences and using robust parametric procedures
\parencite[as implemented in][]{pernet2011limo}. More modern still, applying (possibly
non-linear) multilevel models can further increase the power, flexibility, and robustness in
modeling EEG data. Model-based approaches represent the most challenging, but rewarding
ways of data analysis because they directly link to theory. Regardless of whether one uses
machine learning to classify based on single-trials; multilevel, model-based, or other
approaches trying to illuminate cognitive processes on a single-trial basis
\parencite{makeig2004mining, quiroga2007can, rey2015single}, increasing the signal to
noise ratio in single trials is a formidable, but necessary to overcome challenge.

Based on this brief overview, future work might \textbf{a)} look into how 
model-based approaches to neuroergonomics can inform theoretical debate or increase
predictive accuracy, \textbf{b)} scrutinize the regression-based approach along similar lines as
\textcite{monti2011statistical} did for fMRI research, \textbf{c)} extend the latter by using
regularized estimators, \textbf{d)} demonstrate how mixed effects or multilevel models
decompose the variance of the data in meaningful ways and improve estimation and
prediction accuracy, \textbf{e)} review assumptions of GAMMs and their appropriateness for
EEG data analysis, \textbf{f)} compare the massive univariate approach with GAMMs and judge
their respective informativeness, \textbf{g)} provide an overview on how the univariate
methods discussed here fail to map interesting functional multivariate connections between brain sites,
\textbf{h)} evaluate the suitability of recently developed Bayesian methods for ERP data analysis
\textbf{i)} apply the single-trial framework to workload in order to track potentially
interesting dynamics on a finer scale, and \textbf{j)} compare novel single-trial
denoising techniques for specific applications \parencite[i.e., an update
of][]{de2012let}.

In sum, the analysis of EEG data is a complex endeavour, providing many pitfalls and thus ample
opportunity for learning and exploration.


\newpage
\section{Technical Appendix}

\subsection{Convolution}
Think about a function or signal, $f$, in the time-domain. Visually, convolution is the process of
taking another function $g$ called kernel, shifting it to the left, and sliding it across $f$.

Concretely, reflect or ``swap'' $g(x) \Rightarrow g(-x)$, and add a time-offset so
it can slide across the $x$-axis, $g(-x + t)$. Then convolution means computing a weighted,
sliding average between the original signal and the kernel

\begin{align}
(f \star g)(t) = \int_{-\infty}^{\infty} f(x)g(t - x)\mathrm{d}t
\end{align}

If $g$ is a symmetric function, this reduces to the cross-correlation. Without proof,
convolution in the time-domain corresponds to multiplication in the frequency domain

\begin{align}
\mathcal{F}(f \star g) = \mathcal{F}(f) \cdot \mathcal{F}(g)
\end{align}

where $\mathcal{F}$ stands for the Fourier transform. Because of the speed of the fast
Fourier transform, convolution is commonly computed by

\begin{align}
(f \star g) = \mathcal{F}^{-1} (\mathcal{F}(f) \cdot \mathcal{F}(g))
\end{align}


\subsection{Fourier transform}
The Fourier transform is a linear transformation decomposing any signal into sine waves
of varying frequencies. It matches the signal with complex exponentials (sine and cosine
waves) of different frequencies. There are four different types, depending on whether the signal is
continuous or discrete and periodic or non-periodic \parencite[see][ch.
2]{freeman2012imaging}. Here I focus on discrete non-periodic signals. Noting the expansion

\begin{align}
e^{ix} &= \sum_{k=0}^{\infty} \frac{(ix)^k}{k!} \\
       &= 1 + ix - \frac{x^2}{2!} - i\frac{x^3}{3!} + \frac{x^4}{4!} + i\frac{x^5}{5!} \ldots \\
       &= \sum_{k=0}^{\infty} \frac{x^{2k}}{2k!} + i \cdot \sum_{k=1}^{\infty} \frac{x^{2k + 1}}{(2k + 1)!} \\
       &= cos(x) + i \cdot sin(x)
\end{align}

where $i = \sqrt{-1}$ allows us to write sine and cosine waves compactly as

\begin{equation}
Ae^{i (2 \pi f t + \phi)} = A[cos(2 \pi f t + \phi) + i \cdot sin(2 \pi f t + \phi)]
\end{equation}

where $A$ is the square root of the power (amplitude), $f$ is the frequency, $t$ is the
time, and $\phi$ is the phase offset. Let $x[n]$, $n = 1, \ldots, N$, be the
digital signal derived by sampling the analog or continuous signal at equally spaced time
intervals $\Delta t$; stated differently, the sampling frequency is $f_s = \frac{1}{\Delta t}$
and the length of the signal is $T = N \cdot \Delta t$.

The (discrete) Fourier transform decomposes any signal into a weighted sum of sine and
cosine waves with frequencies $k \in \{0, 1, \ldots, N-1 \}$; the (complex) coefficients
$X[k]$ are given by

\begin{equation}
X[k] = \sum_{n=0}^{N - 1} x[n] \cdot e^{-i (2 \pi k n / N) }
\end{equation}

The inverse Fourier transform reconstructs the signal and is given by

\begin{equation}
x[n] = \frac{1}{N} \sum_{n=0}^{N - 1} X[k] \cdot e^{i (2\pi k n / N)}
\end{equation}

For more, see \textcite[][ch. 2]{freeman2012imaging} and \textcite[][ch. 7]{downey2016think}.

\subsection{Information theory}
Information theory is a branch of mathematics that goes back to Claude Shannon and the
1950s. How surprising is an event? Shannon defined an event's surprisal as

\begin{equation}
h[X] = \log \frac{1}{p(x)} = -\log p(x)
\end{equation}

which when averaged over the event's distribution is termed \textit{entropy}

\begin{equation}
H[X] = -\mathbb{E}[\log p(x)] = -\sum_{x \in X} p(x) \log p(x)
\end{equation}

Entropy is measured in bits, which is a measure of information; one bit encodes as
much as information as provided by a yes/no question. With continuous variables,
we generalize the notion to \textit{differential entropy}\footnote{However, note that this
makes little sense (only in relative comparisons), and information is defined on
a discrete domain; after all, having an infinite amount of digits after the comma,
a continuous number is able to transmit an infinite amount of information.}.

Using this framework, we can introduce a notion of similarity between two probability
distributions, called the \textit{Kullback-Leibler} divergence; which is not symmetric
and thus not a real distance. It is defined as

\begin{equation}
D_{KL}[p||q] = \sum_{x \in X} p(x) \log \frac{1}{q(x)} \mathrm{d}p(x)
\end{equation}

The most popular measure of \textit{linear dependence} is the correlation coefficient;
generalizing the notion of dependence, \textit{mutual information} can be used.

\begin{equation}
I[X:Y] = D_{KL}[p(x,y)||p(x)p(y)] = \sum_{x \in X}\sum_{y \in Y}p(x, y) \log \frac{p(x,y)}{p(x)p(y)}
\mathrm{d}x \mathrm{d}y
\end{equation}

For a brief history on the application of information theory to neuroscience, see
\textcite{dimitrov2011information}; for a review and a new method for efficiently
calculating mutual information, see \textcite{ince2016statistical}; for an excellent
more general introduction, see \textcite{stone2015information}.


\subsection{Principal Component Analysis}
The goal of principal component analysis is to project the data $X$ onto a new space $Y
= PX$ that represents our data using an orthogonal basis with axes along the directions of
maximal variance.

Note that a matrix' eigenvector does not change direction when multiplied by the matrix
$A\vec{\nu} = \lambda\vec{\nu}$. Letting $E$ be a matrix of eigenvectors, and $D$ be a
diagonal matrix of corresponding eigenvalues, we can write

\begin{align}
AE &= ED \\
A &= EDE^{-1} = EDE^T
\end{align}

where we have assumed that A is a symmetric matrix, which implies that $E$ is orthogonal.

\begin{align}
\mathrm{Cov}[Y] &= \mathrm{Cov}[PX] \\
                &= P \mathrm{Cov}[X] P^{T} \\
                &= E^T \mathrm{Cov}[X] E \\
                &= E^T (E D E^T) E = D
\end{align}

Thus the eigenvalues of the covariance matrix of the data gives the variance in the
projected space. We can reduce the dimensionality of the data by only keeping the first
$k$ columns of $E$, and then projecting $Y = E_k^T X$.

For a good tutorial on PCA, see \textcite{shlens2014PCA}.

\subsection{Independent Component Analysis}
While PCA merely decorrelates the data, ICA removes higher order dependencies such as
mutual information and does not require an orthogonal basis.
Concretely, the problem is one of blind source separation. We assume that the data arise from a linear
mixture of sources, $x = As$, but we neither know $A$ nor $s$ -- the problem is not
identifiable. We want to find the \textit{unmixing} matrix $W = A^{-1}$ such that $\hat s = Wx$. 
To achieve identifiability, we assume that $\mathrm{Cov}[s] = \mathrm{Cov}[Wx] =
\mathbb{I}$. Via a singular value decomposition we see that $A^{-1} = (UDV^{T})^{-1} = VD^{-1}U^{T}$.

Due to our assumption we see that $W = VD^{-1/2}E^{T}$ because then it holds that

\begin{align}
\mathrm{Cov}[Wx] &= W(EDE^T)W^T \\
                 &= VD^{-1/2}E^T (EDE^T) ED^{-1/2}V^T = \mathbb{I}
\end{align}

The matrix $W$ does two operations; first, it \textit{whitens} the data $X$ such that
$\mathrm{Cov}[X] = \mathbb{I}$. Denote the whitened data as $x_w = D^{-1/2}E^Tx$
Second, it rotates the data. But how?

We choose $V$ such that the rotated data minimizes the
\textit{multi-information} of the sources $\textbf{s} = [s_1, \ldots, s_n]$.
Multi-information generalizes the notion of mutual
independence to $n$ probability distributions; minimizing it means maximizing the independence
between the probability distributions of the source signals.

\begin{align}
I[\textbf{s}] &= \int_{s \in \mathcal{S}} p(\textbf{s}) \log \frac{p(\textbf{s})}{\prod_s p(s)}
\mathrm{d}\textbf{s} \\
&= \int_{s \in \mathcal{S}} p(\textbf{s}) \log p(\textbf{s}) \mathrm{d}\textbf{s} -
\int_{s \in \mathcal{S}} p(\textbf{s}) \sum_{i=1}^n \log p(s_i) \mathrm{d}\textbf{s} \\
&= - h[\textbf{s}] + \sum_{i=1}^n h[s_i] = \sum_{i=1}^n h[s_i] - h[\textbf{s}] \\
&= \sum_{i=1}^n h[(Vx_w)_i] - h[Vx_w] = \sum_{i=1}^n h[s_i] - (h[x_w] + \log |V|)
\end{align}

where the equivalence of $h[Vx_w] = h[x_w] + \log |V|$ is due to a change of
variables. Since a rotation matrix is orthogonal, its log determinant is zero.
Additionally we can drop $h[x_w]$ because it is a constant, leaving

\begin{equation}
V = \underset{V}{\text{argmin}} \sum_{i=1}^n h[(Vx_w)_i]
\end{equation}

In total, ICA whitens the data and subsequently rotates it such that the marginal
entropies of the source components are minimized. Another way to say this is that ICA
tries to find directions that maximize the \textit{non-gaussianity} of the source
components, because the Gaussian distribution has the highest entropy (among all
distributions with equal variance).

Note that ICA equals PCA for gaussian data because uncorrelatedness implies independence
for gaussian random variables -- there are no further higher-order dependencies fueling
the mutual information machinery. For good tutorials on ICA, see \textcite{shlens2014ICA}
and \textcite{hyvarinen2000independent}.


\subsection{Linear Discriminant Analysis}
There are different ways to think about linear discriminant analysis. Here I motivate
it as a Bayes classifier in a two class classification setting. Given the predictors,
choose the class that has the highest posterior probability.

Note the law of total covariance

\begin{align}
SS_{total} &= SS_{within} + SS_{between} \\
\mathrm{Cov}[X] &= \mathbb{E}[\mathrm{Cov}[X|J]] + \mathrm{Cov}[\mathbb{E}[X|J]]
\end{align}

and Bayes' rule, which follows from the \textit{sum rule} and \textit{product rule} of
probability

\begin{align}
&P(B) = \sum_{A} P(B|A)P(A) \\
&P(A, B) = P(A|B)P(B) = P(B|A)P(A) \\
&\Rightarrow \underbrace{P(A|B)}_{\text{posterior}} =
\frac{\overbrace{P(B|A)}^{\text{likelihood}} \overbrace{P(A)}^{\text{prior}}}
{\underbrace{\sum_{A}P(B|A)P(A)}_{\text{marginal likelihood}}}
\end{align}

Using class labels $0$ and $1$, denote the class conditional covariances as $C_0 =
\mathrm{Cov}[X|J=0]$ and $C_1 = \mathrm{Cov}[X|J=1]$, the class conditional means as
$\mu_0 = \mathbb{E}[X|J=0]$ and $\mu_1 = \mathbb{E}[X|J=1]$, and the priors for the
respective classes as $\pi_0$ and $\pi_1$. Linear discriminant analysis assumes
that $C_0 = C_1$, and that the predictors follow a multivariate normal distribution,
$X_j \sim \mathrm{N}(\mu_j, C_j)$ with $j \in \{0, 1\}$. Recall its shape

\begin{align}
f(x^d|\mu, C) &= (2\pi)^{-d/2} |C|^{-1/2} exp \left(-\frac{1}{2}(x - \mu)^T C^{-1} (x - \mu) \right )
\end{align}

where $d$ is the dimensionality of the features. Turning the Bayesian handle and
classifying given a specific feature $x$ results in 

\begin{align}
p(J = 0|X = x) &= \frac{p(x|J = 0)\pi_0}{p(x|J = 0)\pi_0 + p(x|J = 1)\pi_1} \\[1.5ex]
p(J = 1|X = x) &= \frac{p(x|J = 1)\pi_1}{p(x|J = 0)\pi_0 + p(x|J = 1)\pi_1} \\[1.5ex]
&\Rightarrow \frac{p(J = 0|X = x)}{p(J = 1|X = x)} = \frac{p(x|J = 0)\pi_0}{p(x|J = 1)\pi_1}
\end{align}

Let $p_0 := p(J = 0|X = x)$ and $p_1 := p(J = 0|X = x)$. Simplifying the problem by
taking logs and using $C_0 = C_1$ yields

\begin{align}
\log \frac{p_0}{p_1} &= \log \left( (2\pi)^{-d/2} |C|^{-1/2} \right) - \frac{1}{2}
(x - \mu_0)^T C^{-1} (x - \mu_0) \\
&- \log \left( (2\pi)^{-d/2} |C|^{-1/2} \right) + \frac{1}{2} (x -
\mu_1)^T C^{-1}(x - \mu_1) + \log \frac{\pi_0}{\pi_1} \\
&= -\frac{1}{2} (x - \mu_0)^T C^{-1}(x - \mu_0) + \frac{1}{2}
(x - \mu_1)^T C^{-1} (x - \mu_1) + \log \frac{\pi_0}{\pi_1} \\
&= x^T C^{-1} u_0 - \frac{1}{2} u_0^T C^{-1} u_0^T 
-x^T C^{-1} u_1 + \frac{1}{2} u_1^T C^{-1} u_1^T + \log \frac{\pi_0}{\pi_1}\\
&= x^T C^{-1} (u_0 - u_1) - \frac{1}{2} (u_0 + u_1)^T C^{-1} (u_0 - u_1) +
\log \frac{\pi_0}{\pi_1}
\end{align}

a function linear in $x$. If we were to assume unequal covariances across
classes, the function would be quadratic in $x$, and the resulting classifier
would be called Quadratic Discriminant Analysis (QDA). Assuming that all
features are independent, $p(x_1, \ldots, x_N) = \prod_{i=1}^Np(x_i)$, would result in
the naive Bayes classifier.

The most challenging objective with discriminant analysis is to accurately estimate
the covariance; commonly, this is done using the unbiased empirical covariance estimator
$\hat \Sigma= \frac{1}{N-1} \sum_{i=1}^N (x_i - \hat \mu) (x_i - \hat \mu)^T$ with $\mu =
\frac{1}{n} \sum_{i=1}^N x_i$. However, with a high-dimensional features space as in EEG,
this estimation has high variance. For this reason, one regularizes the estimator
by shrinking it towards the scalar matrix

\begin{equation}
\hat \Sigma_r = (1 - \gamma) \hat \Sigma + \gamma \hat \sigma^2 \mathbb{I}
\end{equation}

with tuning parameter $\gamma \in [0, 1]$ and $\hat \sigma^2 = \text{trace}(\hat \Sigma) /
d$. $\gamma = 0$ results in classical linear discriminant analysis; for more,
see \textcite[][pp. 818]{blankertz2011single}.


\subsection{Regularization}
This provides a slightly different look at regularization.
What is the maximum likelihood estimate for $\theta$ in a coin flip experiment where we
observe $k = 3$ heads in $n = 3$ flips? It is $\theta = k / n = 1$, which is ridiculous. Using
Bayesian inference, the problem setup is

\begin{align}
p(\theta|k, n) = \frac{p(k|\theta, n)p(\theta)}{\int_{\theta} p(k|\theta,
n)p(\theta)\mathrm{d}\theta}
\end{align}

Specifying $\theta \sim \mathrm{Beta}(a = 1, b = 1)$ as prior distribution corresponds to a
uniform prior over $\theta$. Since the beta distribution is conjugate for the binomial
likelihood (our coin toss experiment), we arrive at posterior distribution by simple
arithmetic $\theta|k, n \sim \mathrm{Beta}(a + k, b + n - k)$, with a posterior mean of
$\theta_{MAP} = \frac{a}{a + b} = .8$, a value less ridiculous. This process of
\textit{taming one's estimators} is called \textit{regularization}, and has a natural
Bayesian interpretation. For more on Bayesian inference, see
\textcite{jackman2009bayesian, mcelreath2016statistical} and \textcite{etz2015bayes}.


\subsection{Linear regression}
Linear regression is the most important idea in supervised learning, the branch of machine
learning that tries to learn a function for predicting an outcome given certain inputs, $y
= f(x) + \epsilon$. Linear regression restricts $f(x)$ to be a linear function in the
coefficients $\beta$, $f(x) = \sum_{i=1}^n \langle x_i, \beta \rangle = X\beta$

\begin{equation}
    \begin{pmatrix}
      y_1 \\
      y_2 \\
      \vdots \\
      y_n
    \end{pmatrix}
=
    \begin{pmatrix}
      x_{11} & x_{12} & \ldots & x_{1p} \\
      x_{21} & x_{22} & \ldots & x_{2p} \\
      \vdots & \vdots & \ddots & x_{2p} \\
      x_{n1} & x_{n2} & \ldots & x_{np}
    \end{pmatrix}
\cdot
    \begin{pmatrix}
      \beta_0 \\
      \beta_1 \\
      \vdots \\
      \beta_p
    \end{pmatrix}
\end{equation}

Linear regression models the outcome conditional on the predictors as a (multivariate) gaussian,
$y|X,\beta \sim \mathcal{N}(X\beta, \sigma^2\mathbb{I})$, which can be written as $y =
X\beta + \epsilon$ where $\epsilon \sim \mathcal{N}(0, \sigma^2)$. In addition to this
\textit{heteroscedasticity} requirement, linear regression assumes \textit{weak exogeneity}, that is,
the predictors are not a random variable but fixed, i.e. $\mathbb{E}(X) = X$.

Using a principled loss function based on information theory called \textit{cross entropy}
reduces to the familiar sum of squares error function in case of linear regression

\begin{align}
L(\beta) &= \sum_{i=1}^n \log \mathcal{N}(y_i, \sigma^2\mathbb{I}|\langle x_i, \beta \rangle) \propto
\sum_{i=1}^n (y_i - \langle x_i, \beta \rangle)^2 \\
&= (y - X\beta)^T (y - X\beta)
\end{align}

Minimizing this expression over $\beta$ yields a simple closed form solution

\begin{align}
&\frac{\partial}{\partial \beta} (y - X\beta)^T(y - X\beta) \stackrel{!}{=} 0 \\
\Leftrightarrow \, &\frac{\partial}{\partial \beta} \left (y^Ty - 2X^T\beta^Ty +
\beta^TX^TX\beta \right ) \stackrel{!}{=} 0 \\
\Leftrightarrow \, &0 - 2X^TX\beta + 2X^Ty = 0 \\
\Leftrightarrow \, &2X^TX\beta = 2X^Ty \\
\Leftrightarrow \, &\beta = (X^TX)^{-1} X^Ty
\end{align}

Speaking in terms of EEG data, we can generalize this to do regression not just at a
single point in time, but across $t$ time points:

\begin{equation}
    \begin{pmatrix}
      y_{11} & y_{12} & \ldots & y_{1t} \\
      y_{21} & y_{22} & \ldots & y_{2t} \\
      \vdots & \vdots & \ddots & y_{2t} \\
      y_{n1} & y_{n2} & \ldots & y_{nt}
    \end{pmatrix}
=
    \begin{pmatrix}
      x_{11} & x_{12} & \ldots & x_{1p} \\
      x_{21} & x_{22} & \ldots & x_{2p} \\
      \vdots & \vdots & \ddots & x_{2p} \\
      x_{n1} & x_{n2} & \ldots & x_{np}
    \end{pmatrix}
\cdot
    \begin{pmatrix}
      \beta_{11} & \beta_{12} & \ldots & \beta_{1t} \\
      \beta_{21} & \beta_{22} & \ldots & \beta_{2t} \\
      \vdots & \vdots & \ddots & \beta_{2p} \\
      \beta_{p1} & \beta_{p2} & \ldots & \beta_{pt}
    \end{pmatrix}
\end{equation}


Similarly, we adjust the loss function to this multivariate case

\begin{align}
L(\textbf{B}) &= \sum_{i=1}^n \sum_{t=1}^T (y_{it} - \langle x_{i\cdot}, \beta_{\cdot t}
\rangle)^2 \\
&= \textbf{tr}[(\textbf{Y} - \textbf{XB})^T (\textbf{Y} - \textbf{XB})]
\end{align}

which leads to an equally concise solution

\begin{equation}
\hat{\textbf{B}} = (\textbf{X}^T \textbf{X})^{-1} \textbf{X}^T \textbf{Y}
\end{equation}

Since t-tests and ANOVA and all that are just variants of linear regression with dummy
coding, framing them as a regression problem provides more flexible modeling (see main
text).

In general, the \textit{maximum-likelihood estimate} is prone to overfit the data, which can
be avoided by introducing a penalty on the size of the regression weights (except the
coefficient that encodes the intercept).

\begin{align}
\hat \beta &= \underset{\beta} {\text{argmin}} \, \left( \sum_{i=1}^n (y_i - \beta_0 -
\langle x_i , \beta \rangle)^2 \right) \, \, \, \ldots \, \text{least squares }\\[1.5ex]
\hat \beta &= \underset{\beta} {\text{argmin}} \, \left( \sum_{i=1}^n (y_i - \beta_0 -
\langle x_i , \beta \rangle)^2 + \lambda \sum_{j=1}^p \beta_j^2 \right) \, \, \, \ldots \, \text{ridge}
\\[1.5ex]
\hat \beta &= \underset{\beta} {\text{argmin}} \, \left( \sum_{i=1}^n (y_i - \beta_0 -
\langle x_i , \beta \rangle)^2 + \lambda \sum_{j=1}^p |\beta_j| \right) \, \, \, \ldots \, \text{lasso}
\end{align}

$\lambda$ is a hyper-parameter that is often chosen by cross-validation.
While ridge regression shrinks coefficients towards each other, the lasso shrinks
coefficients to zero, and thus is extremely powerful in high-dimensional
\parencite[see][ch. 3]{hastie2009elements}. Ridge regression has a closed-form solution,
$\hat \beta = (X^TX + \lambda \mathbb{I})^{-1} X^Ty$, and was initially proposed so that
estimation works even when $X$ is not full-rank. The lasso does not have a closed form
solution but is still a convex optimization problem \parencite{tibshirani1996regression}.

Note that, from a Bayesian perspective, the ridge solution is given by the
\textit{maximum a posteriori} estimate using a normal prior,
while the lasso estimate results when choosing a Laplace prior \parencite[cf.][]{park2008bayesian}.

\subsection{Linear mixed effects models}
There is quite some naming controversy around mixed effects models (for example, see
\href{http://andrewgelman.com/2005/01/25/why_i_dont_use/}{here}). The general idea is,
in addition to having coefficients that are common across groups, to also include
coefficients that vary across groups. Take a simple regression model where $N$ participants
indexed by $j$ responded to $I$ trials indexed by $i$ in which words of different lengths
were presented, and reaction time measured.

We can distinguish three possible estimation techniques, either a) averaging
over all participants and computing a single mean, $y_{ij} \sim \mathcal{N}(\beta_0,
\sigma^2)$, termed \textit{pooling}, or b) computing a single mean for each participant seperately,
$y_{ij} \sim \mathcal{N}(\beta_{0j}, \sigma^2)$, termed \textit{no pooling}, or,
finally, c) estimate a mean for each participant, but regularize these estimates with a
prior, $y_{ij} \sim \mathcal{N}(\beta_{0j}, \sigma^2)$, where $\beta_{0j} \sim
\mathcal{N}(\mu, \omega^2)$, termed \textit{partial pooling} or hierarchical model.
In the latter model, $\mu$ denotes the grand participant average, and $\omega^2$ denotes the between group
variance. In the hierarchical model, we have specified a model for parameters -- the participant means --
in addition to our model for the data. We can denote the former as level 2, and the latter
as level 1. Estimating both levels within the same model is what I have
called ``proper'' hierarchical modeling in the main text, which yields more accurate
estimation because of the regularizing prior over the participant means
\parencite{gelman2012multilevel, efron1977stein}.

Extending this hierarchical model into a \textit{multilevel} model entails adding
predictors at the 2 level. Assume our participants responded to words of different length,
and we are interested in how word saliency influences reaction time. Adding reaction time as
a \textit{fixed effect} would result in the following model

\begin{align}
y_{ij} &\sim \mathcal{N}(\beta_{0j} + x\beta_1, \sigma^2) \\
\beta_{0j} &\sim \mathcal{N}(\beta_0, \omega^2)
\end{align}

where we still allow the participants mean to vary, but not the effect of word saliency.
Extending this to have word saliency as a \textit{random effect} would result in 

\begin{align}
y_{ij} &\sim \mathcal{N}(\beta_{0j} + x\beta_{1j}, \sigma^2) \\
\textbf{b}_j &\sim \mathrm{MvN}(\textbf{b}, \Sigma)
\end{align}

where $\textbf{b}_j = (\beta_{0j}, \beta_{1j})$ and $\Sigma$ denotes the covariance matrix,
specifying possible dependencies, i.e. correlation, between mean reaction time and effect of word saliency.

Another terminology, which is usually associated with the classical estimation of
these models, extends the usual regression formula by writing the conditional (multivariate)
distribution of $Y$ given the realized random effects $\mathcal{B} = \textbf{b}$

\begin{align}
Y | \textbf{b} \sim \mathcal{N}(X\beta + Z\textbf{b}, \mathbb{I}\sigma^2)
\end{align}

where $\beta$ denote effects that are fixed across units and \textbf{b} denote effects
that vary across unit. $X$ is now the design matrix for the fixed effects, while $Z$ is
the design matrix for the random effects.

Casting our previous example in this terminology, and assuming that $\mathcal{B} \sim
\mathrm{MvN}(0, \Sigma)$, our design matrices would be

\begin{equation}
X = \begin{pmatrix}
      1 & x_{12} \\
      \vdots & \vdots \\
      1 & x_{p2}
    \end{pmatrix},
Z = \begin{pmatrix}
    1 & 0 \\
    0 & 1
    \end{pmatrix}
\end{equation}

where $x_{12}, \ldots, x_{p2}$ denotes the word saliency. Doing the computation becomes
clear that the varying or random effects offset the common effects on a participant by
participant basis

\begin{align}
y_{ij} &=
\begin{pmatrix}
  1 & x_{12} \\
  \vdots & \vdots \\
  1 & x_{p2}
\end{pmatrix}
\cdot 
\begin{pmatrix}
  \beta_{0} \\
  \beta_{1}
\end{pmatrix}
+
\begin{pmatrix}
  1 & 0 \\
  0 & 1 
\end{pmatrix}
\cdot
\begin{pmatrix}
  b_{0j} \\
  b_{1j}
\end{pmatrix} \\
y_{ij} &= \beta_0 + x\beta_1 + b_{0j} + b_{1j}
\end{align}

These models provide a powerful means of data analysis. For an overview and
implementation on how to estimate these using classical statistics, see
\textcite{bates2014fitting}; for a practical tutorial in the same spirit, see
\textcite{baayen2008mixed}. For a tutorial on how to estimate these models using Bayesian
tools, see \textcite{sorensen2015bayesian}.


\subsection{Splines and General additive models}
One can model non-linear functions in linear regression by including non-linear transforms
of the predictors, relaxing some of the rigidity linearity implies. However, these
transformations are \textit{global}, and it might be hard to find the right
transformations. Splines are piecewise polynomial functions that are fit to the data and
allow increased flexibility. They are connected via knots, but because it is difficult to
select how many knots are needed, i.e. how many seperate polynomial functions are needed,
\textit{smoothing splines} avoid the knot selection problem by regularizing the
``wiggliness'' of the function.

Concretely, we optimize the following penalized residual sum of squares expression

\begin{align}
PRSS = \sum_{i=1}^N (y_i - f(x_i))^2 + \lambda \int \{f''(t)\}^2 \mathrm{d}t
\end{align}

where the first term measures closeness to the data and the second term penalizes the
curvature of the function. If $\lambda = 0$, then we can fit any function to the data,
while when $\lambda = 0$, this reduces to least squares
\parencite[see][pp. 151]{hastie2009elements}. While defined on an infinite dimensional
function space comprised of all functions that have a squared second derivative, it turns
out that this has a unique minimizer, but showing that is beyond this paper (and, currently, me).

For excellent, hands-on explanations see Kim Larsen's
\href{http://multithreaded.stitchfix.com/blog/2015/07/30/gam/}{blog post} and Austin
Rochford's \href{http://austinrochford.com/posts/2015-08-29-additive.html}{blog post}.
Jacolien van Rij provides an
\href{http://jacolienvanrij.com/Tutorials/GAMM.html}{overview} on modeling time series data with GAMMs.


\newpage
\section{Reader's appendix}
This short appendix details things I have found useful in writing this paper. For easy
reading, I liked \textcite{cohen2015cycles} for some EEG background, and
\textcite{lyons2014essential} for a signal processing starter. Having never taken a
class on how to analyze neural time series data, I have found Mike Cohen's book to
be an excellent guide \parencite{cohen2014analyzing}; he also has videos on his webpage,
see \href{http://www.mikexcohen.com/lectures.html}{here}. The first few chapters in
\textcite{luck2014introduction} provided me with necessary background I lacked on ERP
modeling, while the last few chapters detailed the standard approach to statistical
analysis; as prices for textbooks go, it is also very cheap. For more on signal processing,
I enjoyed parts of \textcite{downey2016think} and the beautiful visualizations
\href{https://jackschaedler.github.io/circles-sines-signals/}{here}; more specifically
tuned to EEG, I recommend the first chapters of \textcite{freeman2012imaging}. Writing this paper made me
realize just how spellbound researchers are by the countless MATLAB toolboxes\footnote{Yes,
I realize that figure 1 was made with MATLAB.}, and that
Python is the only real contender in the space of neuroscience and signal processing.
Because using open, general purpose tools is important, I recommend
\textcite{mckinney2012python} and the \href{http://martinos.org/mne/stable/index.html}{MNE}
package \parencite{gramfort2013mne, gramfort2014mne}.

Further reading:

\begin{itemize}
    \item \fullcite{makeig2004mining}
    \item \fullcite{herrmann2014time}
    \item \fullcite{smith2015regressiona}
\end{itemize}


\printbibliography

\end{document}

%
% Please see the package documentation for more information
% on the APA6 document class:
%
% http://www.ctan.org/pkg/apa6
%

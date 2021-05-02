---
permalink: /papers/analysing-energy-detector-diversity-receivers-for-spectrum-sensing/
layout: page
title: Analysing energy detector diversity receivers for spectrum sensing
---

# Abstract

The analysis of energy detector systems is a well studied topic in the literature: numerous models have been derived describing the behaviour of single and multiple antenna architectures operating in a variety of radio environments. However, in many cases of interest, these models are not in a closed form and so their evaluation requires the use of numerical methods. In general, these are computationally expensive, which can cause difficulties in certain scenarios, such as in the optimisation of device parameters on low cost hardware. The problem becomes acute in situations where the signal to noise ratio is small and reliable detection is to be ensured or where the number of samples of the received signal is large. Furthermore, due to the analytic complexity of the models, further insight into the behaviour of various system parameters of interest is not readily apparent.

In this thesis, an approximation based approach is taken towards the analysis of such systems. By focusing on the situations where exact analyses become complicated, and making a small number of astute simplifications to the underlying mathematical models, it is possible to derive novel, accurate and compact descriptions of system behaviour. Approximations are derived for the analysis of energy detectors with single and multiple antennae operating on additive white Gaussian noise (AWGN) and independent and identically distributed Rayleigh, Nakagami-m and Rice channels; in the multiple antenna case, approximations are derived for systems with maximal ratio combiner (MRC), equal gain combiner (EGC) and square law combiner (SLC) diversity. In each case, error bounds are derived describing the maximum error resulting from the use of the approximations. In addition, it is demonstrated that the derived approximations require fewer computations of simple functions than any of the exact models available in the literature. Consequently, the regions of applicability of the approximations directly complement the regions of applicability of the available exact models. Further novel approximations for other system parameters of interest, such as sample complexity, minimum detectable signal to noise ratio and diversity gain, are also derived.

In the course of the analysis, a novel theorem describing the convergence of the chi square, noncentral chi square and gamma distributions towards the normal distribution is derived. The theorem describes a tight upper bound on the error resulting from the application of the central limit theorem to random variables of the aforementioned distributions and gives a much better description of the resulting error than existing Berry-Esseen type bounds. A second novel theorem, providing an upper bound on the maximum error resulting from the use of the central limit theorem to approximate the noncentral chi square distribution where the noncentrality parameter is a multiple of the number of degrees of freedom, is also derived.

# Free/open access

You can download a copy of the thesis [here](https://cora.ucc.ie/handle/10468/1425).

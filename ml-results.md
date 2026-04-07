# ML Results

## Final Model

My final model is a random forest with 500 trees, trained on all available predictors after imputing missing values. I chose it over regularized logistic regression because it achieved a meaningfully lower cross-validated log-loss (0.192 vs. 0.200 for lasso and elastic net, and 0.201 for standard logistic regression). The random forest captures nonlinear relationships and interactions between predictors---such as the combination of crime type, stop reason, and location---without requiring me to specify them by hand. In comparison, the penalized linear models performed nearly identically to each other, which suggests that the main gains come not from variable selection but from modeling flexibility. Still, all models only modestly improved upon the baseline of 0.224, which already reflects the difficulty of predicting arrest from stop-level data.

## Predictability of Stop Outcomes

The fact that even a flexible model like random forest achieves only a modest improvement over always predicting the base rate (~6 percent) tells us something substantive about policing. Arrest outcomes are not well predicted by the information officers record at the time of the stop. This may reflect the high degree of officer discretion in deciding whom to stop and whether to arrest. If stops were tightly targeted at individuals likely to be arrested, we would expect much stronger predictability. Instead, the weak signal is consistent with research suggesting that many stops---particularly during the height of New York's stop-and-frisk program---were conducted on broad, loosely defined pretexts such as "furtive movements."

## Should Police Use Predictive Models?

I would argue that deploying such models in policing raises serious concerns. Even if a model could accurately flag high-arrest-probability stops, it would reflect and reproduce existing patterns of enforcement. Because stop-and-frisk was disproportionately directed at Black and Hispanic New Yorkers, any model trained on this data encodes those disparities. Using it to guide future stops risks automating racial profiling under a veneer of objectivity. The low predictability further weakens the case for deployment: if the model cannot meaningfully distinguish who will be arrested, what exactly is it optimizing?

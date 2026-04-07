# ML Results

## Final Model

My final model is XGBoost (gradient boosted trees) with 234 boosting rounds, learning rate of 0.1, and max depth of 6, trained on 62 engineered features. I arrived at this choice after systematically comparing six model specifications via 5-fold cross-validation: logistic regression (0.201), lasso (0.200), elastic net (0.200), random forest (0.192), XGBoost (0.188), and a single-layer neural network (0.201). The regularized linear models performed nearly identically, which suggests that variable selection alone yields limited gains. The tree-based models---random forest and XGBoost---outperformed the linear models by capturing nonlinear patterns and interactions without explicit specification. XGBoost edged out random forest likely because boosting sequentially corrects errors that earlier trees miss, whereas random forest averages independent trees. The neural network, despite its flexibility, performed no better than logistic regression, possibly because the single hidden layer architecture is too constrained for this data.

## Predictability of Stop Outcomes

Even the best model achieves a log-loss of only 0.188, a modest improvement over the baseline of 0.224 from always predicting the arrest rate of about 6 percent. This tells us that arrest outcomes are not well predicted by the information officers record at the time of the stop. If stops were tightly targeted at individuals with a high probability of being arrested, we would expect much stronger predictability. The weak signal is consistent with research suggesting that many stops during New York's stop-and-frisk era were conducted on loosely defined pretexts---"furtive movements" alone accounts for a large share of recorded reasons---rather than individualized suspicion. In short, the data reveal more about the breadth of police discretion than about the determinants of arrest.

## Should Police Use Predictive Models?

I would argue against deploying predictive models in this context. Any model trained on stop-and-frisk data encodes existing enforcement patterns, which disproportionately targeted Black and Hispanic New Yorkers. Using such a model to guide future stops would risk automating racial profiling under a veneer of statistical objectivity. The low predictability further weakens the case: if the model cannot meaningfully distinguish who will be arrested, it offers little operational value while carrying substantial risks of reinforcing biased policing.

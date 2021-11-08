
#### Definition: 
> HyperParameters are numbers tuning models' weight and bias (parameters)



#### Variables

>
> - $\alpha$ : Learning Rate
> - $\beta$ : Momentum Term
> - Learning Rate Decay
> - Number of Hidden Layer
> - Number of nodes
> - Epoch: All sample Forward and Backward Propogate once for weight adjustment
> - Batch Size: Selected sample
> - $\beta_{1}$, $\beta_{2}$ $\in$ (ADAM)  <- *Adaptive moment estimation*
>

#### Tuning Process:
> For Train-Validation-Test Process, we can optimize hyperparameteres in Validation Process
> Weight: 
> - Small Data: 70/30 
> - Medium Data: 60/20/20
> - Large Data: 98/1/1
> 


#### Under and Overfitting
> ![[Pasted image 20211102084111.png]]
> ![[Pasted image 20211102084234.png]]
> ![[Pasted image 20211102084245.png]]


#### Solve Under and Overfitting Problem
> ![[Pasted image 20211102084501.png]]


#### Method
>  Regularization:
>  - Dropout
>  - Data Augmentation
>  - Early Stopping
>  - Normalization

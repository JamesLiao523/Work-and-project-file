	

#### Definition:
> - First-order interative optimization algorithm for finding the minimum of a function. Usually represent Loss Function (Cost).
 ### Gradient Descent Formula:
> 
> <span style="font-size:30;"> $\frac {\partial C} {\partial X} = [ \frac {\partial C} {\partial X_1}, \frac {\partial C} {\partial X_2}, \frac {\partial C} {\partial X_3},...,\frac {\partial C} {\partial X_m}]$   </span>
> 
> While C = Loss Function, X = weight
> -   The gradient shows how much the parameter x needs to change (in positive or negative direction) to minimize C.
#### Visualize Steps:
> 1. Compute the slope (gradient)
> 2. Move the opposite direction with the amount of slope until  it is 0.
> ![[Pasted image 20211107211633.png]]


#### Gradient Descent Types:
>  #### Batch: 
>  Batch Size = Size of Training Set
> - All the training data is taken into consideration to take a single step. 
>
> - Good Application: When function is convex or relatively smooth
>![[Pasted image 20211107212235.png]]

> #### Stochastic
> Batch Size = 1
> - Consider just one sample at a time and iterate optimized weight one by one

> - In the long run, the cost will fluctuate while decreasing
>  ![[Pasted image 20211107221649.png]]

> #### Minibatch- Mix of Stochastic and Batch
>1 < Batch Size < Size of Training Set
> - Use a batch of a fixed number of training samples which is less than the actual dataset




##### Pros and cons
> #### Pros
> - Batch: 
> > 1. Precise (Less oscillations and noises)
> > 2. More stable convergence and error
> > 3. Computationally efficient
> - Stochastic : 
> > 1. Faster than Batch when data is large
> > 2. Easier to fit memory
> > 3. Converge faster than Batch
> > 4. Minimum Value is not local minimums of loss function
> - Mini-Batch : 
>>  1. Easy fits memory
>>  2. Computationally efficient
>>  3. Benefit from vectorization
>>  4. If stuck in local minimums, some noisy steps can lead the way out of them
>>  5. Average of the training samples = stable error gradients and convergence

> #### Cons:
>  - Batch: 
>>  1. Can't handle big data due to memory issue
>>  2. May occur local minimum
> - Stochastic : 
> > 1. Frequent Update thus minimum value is noisy
> > 2. Takes longer time and not efficient to compute (Not vectorized)
> - Mini-Batch : Need experience to adjust batch manually

#### Visualize route 
![[Pasted image 20211107225948.png]]

#### Vanishing and Exploding Gradient Problem on Backpropagation(gradient descent):
> #### Problem
> - The gradients can get smaller and approach zero and eventually leaves the weights of the initial or lower layers nearly unchanged. => **Never converges to the optimum**.
> -  In some cases, the gradients keep on getting larger and larger. => **very large weight updates and causes the gradient descent to diverge.**
> -   If initial weights are less than 1, it decreases exponentially.
> -   If initial weights are more than 1, it increases exponentially.


> ##### Why?
> - Certain activation functions, like the logistic function (sigmoid), The derivitaves may close to 0 when y is close to 0 or 1
> ![[Pasted image 20211107145709.png]]
>  - when the backpropagation algorithm chips in, it virtually has no gradients to propagate backward in the network => **Leave Nothing for Lower Layer**

> ##### Other Problem:
> -  It takes a long time for gradient descent to learn.
> -  This makes training difficult.


#### Resolution

1.  Minibatch:




2.   Gradient Descent + Momentum<span style="font-size:15;">(Expotnetially weighted moving average )</span>:
>![[Pasted image 20211107235214.png]]
>![[Pasted image 20211107235421.png]]


3. RMSprob
> ![[Pasted image 20211107235439.png]]

4. Adam (RMSprob + Momentum)
> ![[Pasted image 20211107235529.png]]

5. Learning Rate Decay
> ![[Pasted image 20211107235546.png]]

6. Batch Normalization

> - Normalize the input before.
> -  Normalize Z before the activation function
> 
> Scaling all Z values as mean=0 and variance 
> ![[Pasted image 20211107235603.png]]



Comparison
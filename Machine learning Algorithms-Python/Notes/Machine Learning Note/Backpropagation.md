### Definition:
> - Use [[Gradient Descent]] method in Neural Network, and optimize weight to get minimum Loss Function
> - The algorithm is used to train a neural network by chain rule


### Back Propagation Concept and Formula:
> Concept:
> 1. Weight => Forward Propogation => Count Error (E)
> 2. If E < Tolerance: End
> 3. If E > Tolerance: Use Error and back propagate => adjust weight => continue1
> 
> Formula:
> ![[Pasted image 20211103101655.png]]
> ![[Pasted image 20211103101746.png]]
> z = value output of neuron
> $e$ = learning rate
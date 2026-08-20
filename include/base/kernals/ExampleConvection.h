#ifndef EXAMPLECONVECTION_H
#define EXAMPLECONVECTION_H

#include "Kernel.h"

// This defines the "ExampleConvection" tool
class ExampleConvection : public Kernel
{
public:
  // This is the "Birth Certificate" (Constructor)
  ExampleConvection(const InputParameters & parameters);

  // This defines what settings the user can type in the .i file
  static InputParameters validParams();

protected:
  // This is where we will put the math for the error (Residual)
  virtual Real computeQpResidual() override;

  // This is where we put the math for the fix (Jacobian)
  virtual Real computeQpJacobian() override;

private:
  // This is a container to store the "velocity" vector
  RealVectorValue _velocity;
};

#endif
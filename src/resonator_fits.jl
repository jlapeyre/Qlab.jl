using LsqFit

#Fitting a biased Lorentzian to amplitude data.

function bias_lorentzian(x, p)
  """
  Returns a five parameter, biased Lorentizian function

  Args:
    x: domain of the returned function
    p: a vector of length 5 with function params --
        (amplitude, frequency, line width, linear skew, offset)
  Returns:
      The computed function.

  See appendix E.4 of Gao\'s thesis (2008)
  """
  return p[1] ./ ((x - p[2]).^2 + (p[3]/2)^2) + p[4]*(x - p[2]) + p[5];
end

function fit_biased_lorentzian(freq, data)
  """
  Fit frequency-amplitude data to a skewed Lorentzian using nonlinear least-squares.

  Args:
    freq: Frequency data.
    data: Data to be fitted.
    alpha: Confidence limit for error calculation. Default 0.95.
  Returns:
    fit: LsqFitResult object.
    fit_function(x): Biased Lorentzian at fitted parameters.
  """
  p0 = initial_guess(freq, data)
  fit = curve_fit(bias_lorentzian, freq, data, p0)
  errors = estimate_errors(fit, 0.95)
  fit_function(x) = bias_lorentzian(x, fit.param)
  return fit, fit_function
end

#Fitting to the resonance circle of a quarter-wave resonator

function fit_resonance_circle(freqs, data)
  """Fit a resonance circle."""
  @assert length(freqs) == length(data) "Frequency and Data vectors must have same length!"
  @assert length(data) > 20 "Too few points."

function calibrate_resonance_circle(freq, data)

function fit_delay(freq, data)
  """Fit overall phase delay imposed by system transfer function.

  Args:
    freq: Frequency data.
    data: Complex S21 data.
  Returns:
    τ: Linear phase delay
  """
  ϕ = unwrap(angle(data))

  function delay_model

function lorentzian_resonance(p, f)
  """
  Return a resonance model in S21 amplitude over the range [x] and with
  parameters [p].

  See appendix E of Gao 2008 p. 155 Eq E.1
  """
  f0 = p[1]; # resonant frequency
  ϕ  = p[2]; # angle offset in the complex plane due to mismatch
  Q  = p[3]; # total quality factor
  Qc = p[4]; # coupling quality facto
  τ  = p[5]; # phase delay
  α  = p[5]; # loss
  A  = p[6]; # amplitude

  return A*exp(1im*α).*exp(-2π*1im*f*τ).*(1 - (Q/abs(Qc))*exp(1im*ϕ)./(1 + 2*1im*Q*(f/f0 - 1)));
end

function initial_guess(xpts, ypts)
  """
  Returns a length five vector with an initial guess of
  Lorentizian function parameters.
  """
  # find offset
  if abs(maximum(ypts) - median(ypts)) <= abs(minimum(ypts) - median(ypts))
        e = median(ypts)
        idx = indmin(ypts)
        direction = -1
    else
        e = median(ypts)
        idx = indmax(ypts)
        direction = 1
  end
  # center frequency
  b = xpts[idx]
  half = direction * abs(median(ypts) - ypts[idx]) / 2.
  if direction == 1
    idx_l = findfirst(x -> x > half, ypts)
    idx_r = findlast(x -> x > half, ypts)
  else
    idx_l = findfirst(x -> x < half, ypts)
    idx_r = findlast(x -> x < half, ypts)
  end
  c = abs(xpts[idx_l] - xpts[idx_r])
  a =  direction * c^2 * abs(ypts[idx] - e) / 4
  # slope of linear skew
  d = (ypts[end] - ypts[1])/(xpts[end] - xpts[1])
  return [a, b, c, d, e];
end

function simulate_resonance(kwargs...)
  """
  Return synthetic data to test fit functions

  Returns: xpts, ypts, curve_params
  """

  f0 = 6.5 + randn();
  Qc = 10000 + randn()*2000;
  Qi = 5e4;
  τ = 1.74*π;
  ϕ = 2.1*π;
  Q = 1 ./ (1/Qi + real(1 ./ Qc*exp(1im*ϕ)));
  α = 1.2;
  A = 0.73;
  df = f0/Q;
  freqs = linspace(f0 - 6*df, f0 + 6*df, 401);
  data = lorentzian_resonance([f0, ϕ, Q, Qc, τ, α, A], freqs);
  # add some noise
  rand_phase = 2π*0.002*randn(length(freqs));
  rand_amp = 0.01*randn(length(freqs));
  data = data.*exp(-1im*rand_phase).*(1+rand_amp);

  return freqs, data, [f0, ϕ, Q, Qc, τ, α, A]
end

function fit_circle(x, y)
  """Algebraic fit of (x,y) points to a circle. See:
      N. Chernov and C. J. Lesort, Least Squares Fitting of Circles,
        Journal of Mathematical Imaging and Vision, 23: 239-252, 2005.

      Args:
        x, y: X and Y points to be fitted to a circle.
      Returns:
        R: Circle radius.
        xc: x-coordinate of circle center.
        yc: y-coordinate of circle center.
  """
  @assert length(x) == length(y) "X and Y vector lengths must be equal for circle fit!"
  n = length(x)
  z = x.^2 + y.^2
  Mx = sum(x)
  My = sum(y)
  Mz = sum(z)
  Mxx = sum(x.^2)
  Myy = sum(y.^2)
  Mzz = sum(z.^2)
  Mxy = sum(x .* y)
  Mxz = sum(x .* z)
  Myz = sum(y .* z)
  M = [Mzz Mxz Myz Mz; Mxz Mxx Mxy Mx; Myz Mxy Myy My; Mz Mx My n];
  B = [0 0 0 -2; 0 1 0 0; 0 0 1 0; -2 0 0 0]
  D, V = eig(M, B)
  D[D .< eps()] = NaN
  ev = V[:, indmin(D)]
  xc = -ev[2]/2/ev[1]
  yc = -ev[3]/2/ev[1]
  R = sqrt(ev[2]^2 + ev[3]^2 - 4*ev[1]*ev[4])/2./abs(ev[1])
  return R, xc, yc
end

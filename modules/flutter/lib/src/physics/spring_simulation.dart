// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the CHROMIUM_LICENSE file.

import 'dart:math' as math;

import 'simulation.dart';
import 'utils.dart';

/// Structure that describes a spring's constants.
///
/// Used to configure a [SpringSimulation].
class SpringDescription {
  /// Creates a spring given the mass, spring constant and the damping coefficient.
  ///
  /// See [mass], [springConstant], and [damping] for the units of the arguments.
  const SpringDescription({
    this.mass,
    this.springConstant,
    this.damping
  });

  /// Creates a spring given the mass (m), spring constant (k), and damping
  /// ratio (ζ). The damping ratio is especially useful trying to determing the
  /// type of spring to create. A ratio of 1.0 creates a critically damped
  /// spring, > 1.0 creates an overdamped spring and < 1.0 an underdamped one.
  ///
  /// See [mass] and [springConstant] for the units for those arguments. The
  /// damping ratio is unitless.
  SpringDescription.withDampingRatio({
    double mass,
    double springConstant,
    double ratio: 1.0
  }) : mass = mass,
       springConstant = springConstant,
       damping = ratio * 2.0 * math.sqrt(mass * springConstant);

  /// The mass of the spring (m). The units are arbitrary, but all springs
  /// within a system should use the same mass units.
  final double mass;

  /// The spring constant (k). The units of the spring constant are M/T², where
  /// M is the mass unit used for the value of the [mass] property, and T is the
  /// time unit used for driving the [SpringSimulation].
  final double springConstant;

  /// The damping coefficient (c).
  ///
  /// Do not confuse the damping _coefficient_ (c) with the damping _ratio_ (ζ).
  /// To create a [SpringDescription] with a damping ratio, use the [new
  /// SpringDescription.withDampingRatio] constructor.
  ///
  /// The units of the damping coefficient are M/T, where M is the mass unit
  /// used for the value of the [mass] property, and T is the time unit used for
  /// driving the [SpringSimulation].
  final double damping;
}

/// The kind of spring solution that the [SpringSimulation] is using to simulate the spring.
///
/// See [SpringSimulation.type].
enum SpringType {
  /// A spring that does not bounce and returns to its rest position in the
  /// shortest possible time.
  criticallyDamped,

  /// A spring that bounces.
  underDamped,

  /// A spring that does not bounce but takes longer to return to its rest
  /// position than a [criticallyDamped] one.
  overDamped,
}

/// A spring simulation.
///
/// Models a particle attached to a spring that follows Hooke's law.
class SpringSimulation extends Simulation {
  /// Creates a spring simulation from the provided spring description, start
  /// distance, end distance, and initial velocity.
  ///
  /// The units for the start and end distance arguments are arbitrary, but must
  /// be consistent with the units used for other lengths in the system.
  ///
  /// The units for the velocity are L/T, where L is the aforementioned
  /// arbitrary unit of length, and T is the time unit used for driving the
  /// [SpringSimulation].
  SpringSimulation(
    SpringDescription desc,
    double start,
    double end,
    double velocity
  ) : _endPosition = end,
      _solution = new _SpringSolution(desc, start - end, velocity);

  final double _endPosition;
  final _SpringSolution _solution;

  /// The kind of spring being simulated, for debugging purposes.
  ///
  /// This is derived from the [SpringDescription] provided to the [new
  /// SpringSimulation] constructor.
  SpringType get type => _solution.type;

  @override
  double x(double time) => _endPosition + _solution.x(time);

  @override
  double dx(double time) => _solution.dx(time);

  @override
  bool isDone(double time) {
    return nearZero(_solution.x(time), tolerance.distance) &&
           nearZero(_solution.dx(time), tolerance.velocity);
  }
}

/// A SpringSimulation where the value of [x] is guaranteed to have exactly the
/// end value when the simulation isDone().
class ScrollSpringSimulation extends SpringSimulation {
  /// Creates a spring simulation from the provided spring description, start
  /// distance, end distance, and initial velocity.
  ///
  /// See the [new SpringSimulation] constructor on the superclass for a
  /// discussion of the arguments' units.
  ScrollSpringSimulation(
    SpringDescription desc,
    double start,
    double end,
    double velocity
  ) : super(desc, start, end, velocity);

  @override
  double x(double time) => isDone(time) ? _endPosition : super.x(time);
}


// SPRING IMPLEMENTATIONS

abstract class _SpringSolution {
  factory _SpringSolution(
    SpringDescription desc,
    double initialPosition,
    double initialVelocity
  ) {
    assert(desc != null);
    assert(desc.mass != null);
    assert(desc.springConstant != null);
    assert(desc.damping != null);
    assert(initialPosition != null);
    assert(initialVelocity != null);
    double cmk = desc.damping * desc.damping - 4 * desc.mass * desc.springConstant;
    if (cmk == 0.0)
      return new _CriticalSolution(desc, initialPosition, initialVelocity);
    if (cmk > 0.0)
      return new _OverdampedSolution(desc, initialPosition, initialVelocity);
    return new _UnderdampedSolution(desc, initialPosition, initialVelocity);
  }

  double x(double time);
  double dx(double time);
  SpringType get type;
}

class _CriticalSolution implements _SpringSolution {
  factory _CriticalSolution(
    SpringDescription desc,
    double distance,
    double velocity
  ) {
    final double r = -desc.damping / (2.0 * desc.mass);
    final double c1 = distance;
    final double c2 = velocity / (r * distance);
    return new _CriticalSolution.withArgs(r, c1, c2);
  }

  _CriticalSolution.withArgs(double r, double c1, double c2)
    : _r = r,
      _c1 = c1,
      _c2 = c2;

  final double _r, _c1, _c2;

  @override
  double x(double time) {
    return (_c1 + _c2 * time) * math.pow(math.E, _r * time);
  }

  @override
  double dx(double time) {
    final double power = math.pow(math.E, _r * time);
    return _r * (_c1 + _c2 * time) * power + _c2 * power;
  }

  @override
  SpringType get type => SpringType.criticallyDamped;
}

class _OverdampedSolution implements _SpringSolution {
  factory _OverdampedSolution(
    SpringDescription desc,
    double distance,
    double velocity
  ) {
    final double cmk = desc.damping * desc.damping - 4 * desc.mass * desc.springConstant;
    final double r1 = (-desc.damping - math.sqrt(cmk)) / (2.0 * desc.mass);
    final double r2 = (-desc.damping + math.sqrt(cmk)) / (2.0 * desc.mass);
    final double c2 = (velocity - r1 * distance) / (r2 - r1);
    final double c1 = distance - c2;
    return new _OverdampedSolution.withArgs(r1, r2, c1, c2);
  }

  _OverdampedSolution.withArgs(double r1, double r2, double c1, double c2)
    : _r1 = r1,
      _r2 = r2,
      _c1 = c1,
      _c2 = c2;

  final double _r1, _r2, _c1, _c2;

  @override
  double x(double time) {
    return _c1 * math.pow(math.E, _r1 * time) +
           _c2 * math.pow(math.E, _r2 * time);
  }

  @override
  double dx(double time) {
    return _c1 * _r1 * math.pow(math.E, _r1 * time) +
           _c2 * _r2 * math.pow(math.E, _r2 * time);
  }

  @override
  SpringType get type => SpringType.overDamped;
}

class _UnderdampedSolution implements _SpringSolution {
  factory _UnderdampedSolution(
    SpringDescription desc,
    double distance,
    double velocity
  ) {
    final double w = math.sqrt(4.0 * desc.mass * desc.springConstant -
                     desc.damping * desc.damping) / (2.0 * desc.mass);
    final double r = -(desc.damping / 2.0 * desc.mass);
    final double c1 = distance;
    final double c2 = (velocity - r * distance) / w;
    return new _UnderdampedSolution.withArgs(w, r, c1, c2);
  }

  _UnderdampedSolution.withArgs(double w, double r, double c1, double c2)
    : _w = w,
      _r = r,
      _c1 = c1,
      _c2 = c2;

  final double _w, _r, _c1, _c2;

  @override
  double x(double time) {
    return math.pow(math.E, _r * time) *
           (_c1 * math.cos(_w * time) + _c2 * math.sin(_w * time));
  }

  @override
  double dx(double time) {
    final double power = math.pow(math.E, _r * time);
    final double cosine = math.cos(_w * time);
    final double sine = math.sin(_w * time);
    return      power * (_c2 * _w * cosine - _c1 * _w * sine) +
           _r * power * (_c2 *      sine   + _c1 *      cosine);
  }

  @override
  SpringType get type => SpringType.underDamped;
}

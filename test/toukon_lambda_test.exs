defmodule ToukonLambdaTest do
  use ExUnit.Case
  doctest ToukonLambda

  test "greets the world" do
    assert ToukonLambda.hello() == :world
  end
end

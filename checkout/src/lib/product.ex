defmodule Checkout.Product do
  @enforce_keys [:id, :name, :price_in_cents]
  defstruct [:id, :name, :price_in_cents]
end

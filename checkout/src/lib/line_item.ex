defmodule Checkout.LineItem do
  alias Checkout.Product

  @enforce_keys [:product, :quantity, :subtotal, :total]
  defstruct [:product, :quantity, :subtotal, :total, discounts: []]

  def build(%Product{} = product, quantity \\ 1) do
    %__MODULE__{
      product: product,
      quantity: quantity,
      subtotal: product.price_in_cents * quantity,
      total: product.price_in_cents * quantity
    }
  end
end

defmodule Checkout.Discount do
  @moduledoc """
  A struct representing a discount configuration.
  """

  @typedoc """
  Represents the size of a bundle for discount application.
  Must be a positive integer (greater than 0).
  """
  @type bundle_size :: pos_integer()

  @typedoc """
  The type of discount to be applied:
    * `:percentage` - A percentage-based discount (e.g., 25% off)
    * `:unit_price` - A fixed amount discount per unit
  """
  @type discount_type :: :percentage | :unit_price

  @type t :: %__MODULE__{
          name: String.t(),
          minimum_quantity: non_neg_integer(),
          discount: number(),
          discount_type: discount_type(),
          products: [String.t()],
          bundle_size: bundle_size()
        }

  @enforce_keys [:name, :discount, :discount_type]
  defstruct [
    :name,
    :discount,
    :discount_type,
    products: [],
    minimum_quantity: 1,
    bundle_size: 1
  ]

  alias Checkout.LineItem

  @doc """
  Applies a discount to a line item.

  The discount is applied to the quantity of items based on the bundle_size.

  There are two types of discounts:
    * `:percentage` - A percentage-based discount (e.g., 25% off)
    * `:unit_price` - A fixed amount discount per unit

  ## Percentage Discount Example

      iex> discount = %Checkout.Discount{
      ...>   name: "25% off pairs",
      ...>   discount: 0.25,
      ...>   discount_type: :percentage,
      ...>   bundle_size: 2
      ...> }
      iex> line_item = Checkout.LineItem.build(
      ...>   %Checkout.Product{
      ...>     id: "PRODUCT1",
      ...>     name: "Product 1",
      ...>     price_in_cents: 1000
      ...>   },
      ...>   3
      ...> )
      iex> Checkout.Discount.apply_discount(discount, line_item)
      %Checkout.LineItem{
        line_item |
        total: 2500,
        discounts: [{discount, 2, 500}]
      }

  ## Price Discount Example

      iex> discount = %Checkout.Discount{
      ...>   name: "£5 off when you buy 2 or more",
      ...>   discount: 500,
      ...>   discount_type: :unit_price,
      ...>   bundle_size: 2
      ...> }
      iex> line_item = Checkout.LineItem.build(
      ...>   %Checkout.Product{
      ...>     id: "PRODUCT1",
      ...>     name: "Product 1",
      ...>     price_in_cents: 1000
      ...>   },
      ...>   3
      ...> )
      iex> Checkout.Discount.apply_discount(discount, line_item)
      %Checkout.LineItem{
        line_item |
        total: 2000,
        discounts: [{discount, 2, 1000}]
      }

  ## Fallback Example

      iex> discount = %Checkout.Discount{
      ...>   name: "£5 off pairs",
      ...>   discount: 500,
      ...>   discount_type: :unknown,
      ...>   bundle_size: 2
      ...> }
      iex> line_item = Checkout.LineItem.build(
      ...>   %Checkout.Product{
      ...>     id: "PRODUCT1",
      ...>     name: "Product 1",
      ...>     price_in_cents: 1000
      ...>   },
      ...>   3
      ...> )
      iex> Checkout.Discount.apply_discount(discount, line_item)
      %Checkout.LineItem{
        line_item |
        total: 3000,
        discounts: []
      }

  """
  @spec apply_discount(t(), LineItem.t()) :: LineItem.t()
  def apply_discount(%__MODULE__{discount_type: :percentage} = discount, %LineItem{} = line_item) do
    discounted_quantity = line_item.quantity - rem(line_item.quantity, discount.bundle_size)

    unit_price_savings = line_item.product.price_in_cents * discount.discount
    discount_amount = ceil(discounted_quantity * unit_price_savings)

    %LineItem{
      line_item
      | total: line_item.total - discount_amount,
        discounts: [{discount, discounted_quantity, discount_amount} | line_item.discounts]
    }
  end

  def apply_discount(%__MODULE__{discount_type: :unit_price} = discount, %LineItem{} = line_item) do
    discounted_quantity = line_item.quantity - rem(line_item.quantity, discount.bundle_size)

    discount_amount = discounted_quantity * discount.discount

    %LineItem{
      line_item
      | total: line_item.total - discount_amount,
        discounts: [{discount, discounted_quantity, discount_amount} | line_item.discounts]
    }
  end

  def apply_discount(_discount, line_item), do: line_item
end

import { computed } from "@vue/reactivity";
import { Ref } from "vue";
import { Asset, AssetAmount, IAssetAmount, Pair } from "../entities";
import { Fraction } from "../entities/fraction/Fraction";
import B from "../entities/utils/B";
import { useField } from "./useField";
import { assetPriceMessage } from "./utils";

export function usePoolCalculator(input: {
  fromAmount: Ref<string>;
  fromSymbol: Ref<string | null>;
  toAmount: Ref<string>;
  toSymbol: Ref<string | null>;
  balances: Ref<IAssetAmount[]>;
  selectedField: Ref<"from" | "to" | null>;
  marketPairFinder: (a: Asset | string, b: Asset | string) => Pair | null;
}) {
  const fromField = useField(input.fromAmount, input.fromSymbol);
  const toField = useField(input.toAmount, input.toSymbol);

  const liquidityPair = computed(() => {
    if (!fromField.fieldAmount.value || !toField.fieldAmount.value) return null;
    return Pair(fromField.fieldAmount.value, toField.fieldAmount.value);
  });

  const aPerBRatioMessage = computed(() => {
    const asset = fromField.asset.value;
    const pair = liquidityPair.value;
    return assetPriceMessage(asset, pair);
  });

  const bPerARatioMessage = computed(() => {
    const asset = toField.asset.value;
    const pair = liquidityPair.value;
    return assetPriceMessage(asset, pair);
  });

  const shareOfPool = computed(() => {
    if (!liquidityPair.value) return "";
    const [ama, amb] = liquidityPair.value.amounts;
    const marketPair = input.marketPairFinder(ama.asset, amb.asset);

    // TODO: Naive calculation need to check this is correct
    // get the sum of the market pair
    const marketPairSum = marketPair
      ? marketPair.amounts.reduce(
          (acc, amount) => amount.add(acc),
          new Fraction("0")
        )
      : new Fraction("0");

    // TODO: Naive calculation need to check this is correct
    // get the sum of the liquidity pair being created
    const liquidityPairSum = liquidityPair.value.amounts.reduce(
      (acc, amount) => amount.add(acc),
      new Fraction("0")
    );

    // TODO: Naive calculation need to check this is correct
    // Work out the total share of the pool by adding
    // all the amounts up and dividing by the liquidity pair
    return `${liquidityPairSum
      .divide(marketPairSum.add(liquidityPairSum))
      .multiply(new Fraction("100"))
      .toFixed(2)}%`;
  });

  const nextStepMessage = computed(() => {
    return "";
  });

  return {
    aPerBRatioMessage,
    bPerARatioMessage,
    shareOfPool,
    nextStepMessage,
    fromFieldAmount: fromField.fieldAmount,
    toFieldAmount: toField.fieldAmount,
    toAmount: input.toAmount,
    fromAmount: input.fromAmount,
  };
}
# PackCheck

An iPhone prototype for comparing packaged food ingredients against terms you want to avoid. The default profile checks for eggs. Add your own terms, separated by commas. The checker uses English ingredient text and matches whole words and phrases.

## Run on an iPhone

1. Install Xcode 16 or later on your Mac and open `PackCheck.xcodeproj`.
2. In the PackCheck target, open **Signing & Capabilities** and choose your Apple development team. If Xcode reports that the bundle identifier is taken, change it to a unique identifier.
3. Connect and select an iPhone running iOS 17 or later, then click **Run**. Follow any device setup prompts in Xcode.
4. Scan a barcode and tap **Look up barcode**. Check the returned product name and flavour against the pack.
5. Photograph the ingredient panel. Correct any errors in the captured text and add any warnings printed separately. The app checks the captured text automatically. Review the full text against the pack and correct any reading errors.

## Translate a label

Scan or paste the original label, including any separate warnings. Turn on **Label needs English translation**, then tap **Translate to English**. Automatic translation uses Apple’s supported language pairs on iOS 18 or later and may prompt you to download a language. Review and correct the English text after translation. Results update automatically. You can enter an English translation manually if automatic translation is unavailable, including on iOS 17.

For a translation test, paste `Ingredientes: harina, azúcar. Puede contener huevos.` With the egg rule on, review the English output for the “may contain eggs” warning. Edit the original and verify that the previous translation clears.

Manual barcode and label entry also work without a supported camera. The camera photo is processed on device. Only the barcode is sent to Open Food Facts for product lookup.

For a first test, enter `Ingredients: flour, sugar, egg powder`. Then try `Ingredients: flour, sugar. MAY CONTAIN EGG`. Check that the result distinguishes an ingredient from a trace warning. To check a different package, clear the product and label first.

The app reports selected ingredient matches and uncertainty. It cannot confirm allergy safety, product certification, or every ingredient synonym. Review the original packaging and manufacturer information for allergy decisions.

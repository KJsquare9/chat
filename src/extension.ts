import * as vscode from 'vscode';

export function activate(context: vscode.ExtensionContext) {
	console.log('Congratulations, your extension "chat" is now active!');

	let disposable = vscode.commands.registerCommand('chat.helloWorld', () => {
		vscode.window.showInformationMessage('Hello World from chat!');

		try {
			// Simulate some operation that could throw an error
			throw new Error('Simulated error');
		} catch (e) {
			// Be more resilient against errors. During development, it's easy to introduce errors that crash the extension.
			// We don't want that to happen in production.
			if (e instanceof Error) {
				vscode.window.showErrorMessage(e.message);
			} else {
				vscode.window.showErrorMessage('An unknown error occurred.');
			}
		}
	});

	context.subscriptions.push(disposable);
}

export function deactivate() {}